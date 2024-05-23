CREATE TABLE IF NOT EXISTS "ticket" (
    "id"        BIGSERIAL NOT NULL PRIMARY KEY,
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
    "id"            BIGSERIAL NOT NULL PRIMARY KEY,
    "name"          VARCHAR(255) NOT NULL CHECK(LENGTH(TRIM(name)) >= 3),
    "description"   VARCHAR(255), 
    "genre"         VARCHAR(10) CHECK (genre IN ('art', 'sport', 'education', 'buisness')),
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

-- for text search
ALTER TABLE "event" ADD COLUMN ts tsvector
    GENERATED ALWAYS AS (to_tsvector('english', description)) STORED;

-- triggers

-- we need to be sure that the event that we are scheduling has the
-- number of seats that is not greater that number of seats in the
-- location that it will take place
CREATE OR REPLACE FUNCTION check_event_seats_less_than_location_seats()
RETURNS TRIGGER AS $$
DECLARE
    max_seats BIGINT;
BEGIN
    SELECT seats INTO max_seats FROM "location" WHERE id=NEW.location_id;

    IF NEW.seats > max_seats THEN
        RAISE NOTICE 'max_seats is currently %', max_seats;
        RAISE NOTICE 'seats is currently %', NEW.seats;
        RAISE EXCEPTION 'not enough seats';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_event_seats BEFORE INSERT ON "event" FOR EACH ROW EXECUTE FUNCTION check_event_seats_less_than_location_seats();

-- materialized view that holds the almost sold out events
-- it it refreshed automatically by trigger "decrement_seats"
CREATE MATERIALIZED VIEW IF NOT EXISTS soon_sold_out_events AS
-- CTE to grab artist list
WITH artist_aggregation AS (
    SELECT 
        event_id, 
        array_agg(artist.name) as artists 
    FROM 
        event_artist 
    LEFT JOIN 
        artist ON artist.id = event_artist.artist_id 
    GROUP BY 
        event_id
)
SELECT 
    e.name as event_name, 
    e.description, 
    e.seats as seats_left, 
    l.name as location_name, 
    aa.artists 
FROM 
    event e 
INNER JOIN 
    location l ON e.location_id = l.id 
LEFT JOIN 
    artist_aggregation aa ON aa.event_id = e.id
    -- almost sold out when < 150
    WHERE e.seats < 150
WITH NO DATA;

-- need to refresh it on the start
REFRESH MATERIALIZED VIEW soon_sold_out_events;

-- this trigger is invoked when ticket is inserted into database.
-- it decrements the number of seats for particular event and potentially
-- refreshes the "soon_sold_out_events" materialzied view
CREATE OR REPLACE FUNCTION decrement_seats() RETURNS TRIGGER AS $$
DECLARE
    current_seats integer;
BEGIN
  UPDATE "event"
  SET seats = seats - 1
  WHERE id = NEW.event_id AND seats > 0
  RETURNING seats INTO current_seats;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No seats available for event_id %', NEW.event_id;
  END IF;

  RAISE NOTICE 'current_seats is currently %', current_seats;
  IF current_seats < 150 THEN
    RAISE NOTICE 'refreshing materialized view';
    REFRESH MATERIALIZED VIEW soon_sold_out_events;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_decrement_seats
AFTER INSERT ON "ticket"
FOR EACH ROW
EXECUTE FUNCTION decrement_seats();

-- This function adds event, it takes all args that are needed to crate event
-- record itself and also arbitrary len of artists ids. 
CREATE OR REPLACE FUNCTION add_event(aname varchar(255), adescription varchar(255), agenre varchar(10), 
    astart_date date, aend_date date, aseats bigint, alocation_id bigint, VARIADIC aartists BIGINT[]) RETURNS void
AS $$
DECLARE
    event_id bigint;
    aartist bigint;
BEGIN
    INSERT INTO event(name, description, genre, start_date, end_date, seats, location_id) VALUES (
        aname, adescription, agenre, astart_date, aend_date, aseats, alocation_id
    ) RETURNING id into event_id;

    FOREACH aartist IN ARRAY aartists
    LOOP
        INSERT INTO event_artist(event_id,artist_id) VALUES(event_id, aartist);
    END LOOP;
END;
$$LANGUAGE plpgsql;


-- load test data
INSERT INTO "location" ("id", "name", "seats", "coordinates") VALUES
(1, 'first place', 100, ST_GeogFromText('POINT(-70.935242 90.730610)')),
(2, 'second place', 150, ST_GeogFromText('POINT(-76.935242 46.730610)')),
(3, 'third place', 200, ST_GeogFromText('POINT(-70.935242 10.730610)')),
(4, 'fourth place', 250, ST_GeogFromText('POINT(-70.935242 20.730610)')),
(5, 'fifth place', 300, ST_GeogFromText('POINT(-79.935242 20.730610)'));

INSERT INTO "event" ("id", "name", "start_date", "end_date", "seats", "location_id", "description", "genre") VALUES
(1, 'Music Concert', '2024-06-01', '2024-06-01', 100, 1, 'A grand music concert featuring famous bands.', 'art'),
(2, 'Tech Conference', '2024-07-15', '2024-07-17', 150, 2, 'Annual tech conference with keynotes and workshops.', 'art'),
(3, 'Food Festival', '2024-08-20', '2024-08-22', 200, 3, 'A festival showcasing gourmet food from around the world and musical.', 'buisness'),
(4, 'Art Exhibition', '2024-09-10', '2024-09-12', 250, 4, 'Exhibition of modern and contemporary art pieces.', 'education'),
(5, 'Book Fair', '2024-10-05', '2024-10-07', 300, 5, 'A fair where you can find books from various genres and authors.', 'art'),
(6, 'Book Fair Super Exclusive', '2024-10-05', '2024-10-07', 50, 3, 'A fair where you can find super exclusive books from various genres and authors.', 'sport');

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
(5, 1),
(4, 2),
(3, 3),
(2, 4),
(1, 5),
(2, 1);

INSERT INTO "ticket" (id, owner_id, event_id, price, currency) VALUES
(1, 1, 5, 50.00, 'USD'),
(2, 2, 4, 75.00, 'EUR'), 
(3, 3, 3, 100.00, 'GBP'),
(4, 4, 2, 120.00, 'PLN'), 
(5, 5, 1, 60.00, 'USD'),
(6, 3, 1, 90.00, 'GBP'),
(7, 3, 6, 190.00, 'GBP');

-- adjust sequence due to manually inserted ids
SELECT setval(pg_get_serial_sequence('"ticket"', 'id'), MAX(id)) FROM "ticket";
SELECT setval(pg_get_serial_sequence('"event"', 'id'), MAX(id)) FROM "event";