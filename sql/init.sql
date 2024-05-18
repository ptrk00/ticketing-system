CREATE TABLE IF NOT EXISTS "ticket" (
    "id"        BIGINT NOT NULL PRIMARY KEY,
    "owner_id"  BIGINT NOT NULL,
    "event_id"  BIGINT NOT NULL,
    "price"     NUMERIC(12,2) CHECK(price > 0),
    "currency"  VARCHAR(3) CHECK (currency IN ('PLN', 'USD', 'EUR', 'GBP'))  
);

CREATE TABLE IF NOT EXISTS "event_artist" (
    "event_id"  BIGINT NOT NULL,
    "artist_id" BIGINT NOT NULL,
    PRIMARY KEY ("event_id", "artist_id")
);

CREATE TABLE IF NOT EXISTS "artist" (
    "id"        BIGINT NOT NULL PRIMARY KEY,
    "name"      VARCHAR(255) NOT NULL CHECK(LENGTH(TRIM(name)) >= 3)
);

CREATE TABLE IF NOT EXISTS "event" (
    "id"            BIGINT NOT NULL PRIMARY KEY,
    "name"          VARCHAR(255) NOT NULL CHECK(LENGTH(TRIM(name)) >= 3),
    "description"   VARCHAR(255), 
    "start_date"    DATE NOT NULL,
    "end_date"      DATE NOT NULL,
    "seats"         BIGINT NOT NULL CHECK(seats > 0), 
    "location_id"   BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS "user" (
    "id"        BIGINT NOT NULL PRIMARY KEY,
    "name"      VARCHAR(255) NOT NULL CHECK(LENGTH(TRIM(name)) >= 3),
    "email"     VARCHAR(255) NOT NULL UNIQUE CHECK(LENGTH(TRIM(email)) >= 3),
    "birthdate" DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS "location" (
    "id"          BIGINT NOT NULL PRIMARY KEY,
    "name"        VARCHAR(255) NOT NULL CHECK(LENGTH(TRIM(name)) >= 1),
    "seats"       BIGINT NOT NULL CHECK(seats > 0),
    "coordinates" GEOGRAPHY(Point, 4326)
);


-- foregin keys
ALTER TABLE
    "event" ADD CONSTRAINT "event_location_id_foreign" FOREIGN KEY("location_id") REFERENCES "location"("id");
ALTER TABLE
    "ticket" ADD CONSTRAINT "ticket_owner_id_foreign" FOREIGN KEY("owner_id") REFERENCES "user"("id");
ALTER TABLE
    "ticket" ADD CONSTRAINT "ticket_event_id_foreign" FOREIGN KEY("event_id") REFERENCES "event"("id");
ALTER TABLE
    "event_artist" ADD CONSTRAINT "event_artist_artist_id_foreign" FOREIGN KEY("artist_id") REFERENCES "artist"("id");
ALTER TABLE
    "event_artist" ADD CONSTRAINT "event_artist_event_id_foreign" FOREIGN KEY("event_id") REFERENCES "event"("id");


ALTER TABLE "event" ADD CONSTRAINT "start_date_before_end_date" CHECK (start_date <= end_date);

-- triggers

CREATE OR REPLACE FUNCTION check_event_seats_less_than_location_seats()
RETURNS TRIGGER AS $$
DECLARE
    max_seats BIGINT;
BEGIN
    SELECT seats INTO max_seats FROM "location" WHERE id=NEW.id;
    -- RAISE NOTICE 'max_seats is currently %', max_seats;
    -- RAISE NOTICE 'seats is currently %', NEW.seats;
    IF NEW.seats > max_seats THEN
        RAISE EXCEPTION 'not enough seats';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_event_seats BEFORE INSERT ON "event" FOR EACH ROW EXECUTE FUNCTION check_event_seats_less_than_location_seats();

ALTER TABLE "event" ADD COLUMN ts tsvector
    GENERATED ALWAYS AS (to_tsvector('english', description)) STORED;

CREATE OR REPLACE FUNCTION decrement_seats() RETURNS TRIGGER AS $$
BEGIN
  -- Decrement the seats in the event table where event_id matches
  UPDATE "event"
  SET seats = seats - 1
  WHERE id = NEW.event_id AND seats > 0;

  -- Ensure that the seats were decremented
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No seats available for event_id %', NEW.event_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_decrement_seats
AFTER INSERT ON "ticket"
FOR EACH ROW
EXECUTE FUNCTION decrement_seats();

-- load test data
INSERT INTO "location" ("id", "name", "seats", "coordinates") VALUES
(1, 'first place', 100, ST_GeogFromText('POINT(-70.935242 90.730610)')),
(2, 'second place', 150, ST_GeogFromText('POINT(-76.935242 46.730610)')),
(3, 'third place', 200, ST_GeogFromText('POINT(-70.935242 10.730610)')),
(4, 'fourth place', 250, ST_GeogFromText('POINT(-70.935242 20.730610)')),
(5, 'fifth place', 300, ST_GeogFromText('POINT(-79.935242 20.730610)'));

INSERT INTO "event" ("id", "name", "start_date", "end_date", "seats", "location_id", "description") VALUES
(1, 'Music Concert', '2024-06-01', '2024-06-01', 100, 1, 'A grand music concert featuring famous bands.'),
(2, 'Tech Conference', '2024-07-15', '2024-07-17', 150, 2, 'Annual tech conference with keynotes and workshops.'),
(3, 'Food Festival', '2024-08-20', '2024-08-22', 200, 3, 'A festival showcasing gourmet food from around the world and musical.'),
(4, 'Art Exhibition', '2024-09-10', '2024-09-12', 250, 4, 'Exhibition of modern and contemporary art pieces.'),
(5, 'Book Fair', '2024-10-05', '2024-10-07', 300, 5, 'A fair where you can find books from various genres and authors.'),
(6, 'Book Fair Super Exclusive', '2024-10-05', '2024-10-07', 300, 3, 'A fair where you can find super exclusive books from various genres and authors.');

INSERT INTO "user" (id, name, email, birthdate) VALUES
(1, 'Alice Smith', 'alice.smith@example.com', '1990-01-15'),
(2, 'Bob Johnson', 'bob.johnson@example.com', '1985-05-23'),
(3, 'Charlie Brown', 'charlie.brown@example.com', '1992-08-12'),
(4, 'Diana Prince', 'diana.prince@example.com', '1988-11-03'),
(5, 'Evan Davis', 'evan.davis@example.com', '1995-04-28');

INSERT INTO "artist" (id, name) VALUES
(1, 'Vincent van Gogh'),
(2, 'Pablo Picasso'),
(3, 'Leonardo da Vinci'),
(4, 'Claude Monet'),
(5, 'Frida Kahlo');

INSERT INTO "event_artist" (event_id, artist_id) VALUES
(5, 1), -- Example: Vincent van Gogh at Event 101
(4, 2), -- Example: Pablo Picasso at Event 102
(3, 3), -- Example: Leonardo da Vinci at Event 103
(2, 4), -- Example: Claude Monet at Event 104
(1, 5); -- Example: Frida Kahlo at Event 105

INSERT INTO "ticket" (id, owner_id, event_id, price, currency) VALUES
(1, 1, 5, 50.00, 'USD'), -- Owner 1, Event 101, Price 50.00 USD
(2, 2, 4, 75.00, 'EUR'), -- Owner 2, Event 102, Price 75.00 EUR
(3, 3, 3, 100.00, 'GBP'), -- Owner 3, Event 103, Price 100.00 GBP
(4, 4, 2, 120.00, 'PLN'), -- Owner 4, Event 104, Price 120.00 PLN
(5, 5, 1, 60.00, 'USD'), -- Owner 5, Event 105, Price 60.00 USD
(6, 3, 1, 90.00, 'GBP'),
(7, 3, 6, 190.00, 'GBP')
