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
    "name"      VARCHAR(255) NOT NULL CHECK(LENGTH(TRIM(name)) >= 3),
    "image_url" VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS "event" (
    "id"                    BIGSERIAL NOT NULL PRIMARY KEY,
    "name"                  VARCHAR(255) NOT NULL CHECK(LENGTH(TRIM(name)) >= 3),
    "description"           VARCHAR(255), 
    "long_description"      VARCHAR(2048),
    "genre"                 VARCHAR(10) CHECK (genre IN ('art', 'sport', 'education', 'buisness')),
    "start_date"            DATE NOT NULL,
    "end_date"              DATE NOT NULL,
    "seats"                 BIGINT NOT NULL CHECK(seats > 0), 
    "location_id"           BIGINT NOT NULL,
    "image_url"             VARCHAR(255)
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
    "coordinates" GEOGRAPHY(Point, 4326), 
    "description" VARCHAR(255),
    "image_url"   VARCHAR(255)
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
    e.image_url as image_url,
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
    ORDER BY e.seats ASC
    LIMIT 3
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

-- view for quering events
CREATE OR REPLACE VIEW event_overview AS 
    SELECT 
        event.id, 
        event.name,
        event.image_url as image_url,
        event.description, 
        start_date, 
        end_date, 
        event.seats as "seats_left", 
        location.name as "location_name",
        event.ts as ts
    FROM "event" 
        INNER JOIN location ON event.location_id = location.id;

CREATE OR REPLACE VIEW event_details AS
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
        e.id,
        e.name as event_name, 
        e.description,
        e.long_description,
        e.image_url,
        e.start_date,
        e.end_date, 
        e.seats as seats_left, 
        l.name as location_name, 
        ST_Y(ST_AsText(l.coordinates::geometry)) as latitude,
        ST_X(ST_AsText(l.coordinates::geometry)) as longitude,
        aa.artists 
    FROM 
        event e 
    INNER JOIN 
        location l ON e.location_id = l.id 
    LEFT JOIN 
        artist_aggregation aa ON aa.event_id = e.id;


-- load test data
INSERT INTO "location" ("id", "name", "seats", "coordinates", "image_url", "description") VALUES
(1, 'Stage', 100, ST_GeogFromText('POINT(-70.935242 90.730610)'), 'https://cdn.pixabay.com/photo/2016/10/03/18/52/stage-1712494_1280.jpg', 'The Stage is an iconic venue known for its outstanding performances and vibrant atmosphere. It has a seating capacity of 100.'),
(2, 'AGH University', 150, ST_GeogFromText('POINT(19.92330738650622 50.06458216297299)'), 'https://www.uczelnie.pl/prezentacje/52/img/1_b.jpg', 'AGH University is a prestigious institution with modern facilities and a seating capacity of 150. It is renowned for its academic excellence.'),
(3, 'Mall', 200, ST_GeogFromText('POINT(-70.935242 10.730610)'), 'https://cdn.pixabay.com/photo/2016/05/26/05/12/shopping-mall-1416500_960_720.jpg', 'The Mall is a popular shopping destination with a variety of stores and a seating capacity of 200. It offers a great shopping experience.'),
(4, 'Random Museum', 250, ST_GeogFromText('POINT(-70.935242 20.730610)'), 'https://cdn.pixabay.com/photo/2017/04/05/01/10/natural-history-museum-2203648_1280.jpg', 'Random Museum showcases a diverse collection of exhibits and artifacts. With a seating capacity of 250, it provides an educational and cultural experience.'),
(5, 'Biblioteka UW', 300, ST_GeogFromText('POINT(21.02476929686503 52.24265017514509)'), 'https://cdn.pixabay.com/photo/2020/02/06/20/01/university-library-4825366_1280.jpg', 'Biblioteka UW is the University of Warsaw library. It has a seating capacity of 300 and offers a vast collection of books and resources for students.');


INSERT INTO "event" ("id", "name", "start_date", "end_date", "seats", "location_id", "description", "genre", "image_url", "long_description") VALUES
(1, 'Music Concert', '2024-06-01', '2024-06-01', 100, 1, 'A grand music concert featuring famous bands.', 'art', 'https://cdn.pixabay.com/photo/2016/11/18/15/44/audience-1835431_960_720.jpg', 'This grand music concert features famous bands from all over the world. Attendees can expect a day full of musical performances, ranging from rock and pop to classical and jazz. The concert aims to bring together music enthusiasts and provide a platform for both emerging and established artists to showcase their talent. In addition to the main stage performances, there will be smaller, more intimate sessions in various corners of the venue, offering a variety of musical experiences. Food and beverages will be available from numerous vendors, ensuring that attendees can enjoy refreshments while listening to their favorite tunes. With its impressive lineup and vibrant atmosphere, this music concert is set to be an unforgettable event.'),
(2, 'Tech Conference', '2024-07-15', '2024-07-17', 150, 2, 'Annual tech conference with keynotes and workshops.', 'buisness', 'https://cdn.pixabay.com/photo/2016/02/03/17/38/coffee-break-1177540_1280.jpg', 'The annual tech conference is a must-attend event for professionals in the technology industry. Over the course of three days, attendees will have the opportunity to attend keynote speeches by industry leaders, participate in hands-on workshops, and network with peers. The conference covers a wide range of topics, including artificial intelligence, cybersecurity, cloud computing, and more. Each day will feature a mix of presentations and interactive sessions designed to provide both theoretical knowledge and practical skills. Participants can also visit the exhibition hall, where leading tech companies will showcase their latest products and innovations. Whether you are a seasoned professional or new to the tech field, this conference offers valuable insights and opportunities for growth.'),
(3, 'Food Festival', '2024-08-20', '2024-08-22', 200, 3, 'A festival showcasing gourmet food from around the world and musical.', 'sport', 'https://cdn.pixabay.com/photo/2014/10/19/20/59/hamburger-494706_960_720.jpg', 'The food festival is a culinary celebration that brings together gourmet food from around the world. Over the course of three days, attendees can sample dishes from various cuisines, each prepared by top chefs. In addition to the delicious food, the festival features musical performances that add to the festive atmosphere. Visitors can participate in cooking workshops, watch live demonstrations, and even meet some of their favorite chefs. There are also competitions where chefs showcase their skills and creativity. With its diverse offerings, the food festival is a perfect event for food lovers and anyone looking to enjoy a fun and flavorful experience.'),
(4, 'Art Exhibition', '2024-09-10', '2024-09-12', 250, 4, 'Exhibition of modern and contemporary art pieces.', 'art', 'https://cdn.pixabay.com/photo/2016/03/15/12/24/student-1258137_960_720.jpg', 'The art exhibition features a stunning collection of modern and contemporary art pieces. Over three days, visitors can explore a wide range of artworks, including paintings, sculptures, and installations. The exhibition aims to provide a platform for artists to showcase their work and for art enthusiasts to discover new and inspiring pieces. In addition to the displayed works, there will be guided tours, artist talks, and interactive sessions where visitors can engage with the art and the artists. The venue itself is designed to enhance the viewing experience, with carefully curated spaces that allow each piece to be appreciated fully. Whether you are an art aficionado or simply curious, this exhibition offers a rich and immersive experience.'),
(5, 'Book Fair', '2024-10-05', '2024-10-07', 300, 5, 'A fair where you can find books from various genres and authors.', 'education', 'https://cdn.pixabay.com/photo/2020/04/17/08/03/books-5053733_960_720.jpg', 'The book fair is a literary event that brings together authors, publishers, and book lovers. Over three days, attendees can browse a wide selection of books from various genres and meet some of their favorite authors. The fair features book signings, panel discussions, and readings, providing a unique opportunity to engage with the literary community. In addition to the books, there will be workshops and seminars on topics such as writing, publishing, and storytelling. The event also includes activities for children, making it a family-friendly outing. Whether you are an avid reader or just looking for a fun and educational experience, the book fair has something to offer.'),
(6, 'Book Fair Super Exclusive', '2024-10-05', '2024-10-07', 50, 3, 'A fair where you can find super exclusive books from various genres and authors.', 'education', 'https://cdn.pixabay.com/photo/2014/09/05/18/32/old-books-436498_1280.jpg', 'The Book Fair Super Exclusive is a premium literary event designed for true book aficionados. Over the course of three days, this exclusive fair offers access to rare and limited-edition books from various genres, along with the chance to meet distinguished authors and publishers. Attendees can participate in intimate book signings, private readings, and exclusive panel discussions. The event also features specialized workshops focusing on rare book collection, preservation, and the art of bookbinding. With its limited seating and exclusive content, the Book Fair Super Exclusive provides a unique and luxurious experience for those passionate about literature. Whether you are a collector or a dedicated reader, this event offers unparalleled access to the world of exclusive books.');


INSERT INTO "user" (id, name, email, birthdate) VALUES
(1, 'Alice Smith', 'alice.smith@example.com', '1990-01-15'),
(2, 'Bob Johnson', 'bob.johnson@example.com', '1985-05-23'),
(3, 'Charlie Brown', 'charlie.brown@example.com', '1992-08-12'),
(4, 'Diana Prince', 'diana.prince@example.com', '1988-11-03'),
(5, 'Evan Davis', 'evan.davis@example.com', '1995-04-28');

INSERT INTO "artist" (id, name, image_url) VALUES
(1, 'Vincent van Gogh', 'https://cdn.pixabay.com/photo/2015/08/02/23/38/agnar-hoeskuldsson-872408_1280.jpg'),
(2, 'Pablo Picasso', 'https://cdn.pixabay.com/photo/2016/11/29/01/34/man-1866572_1280.jpg'),
(3, 'Leonardo da Vinci', 'https://cdn.pixabay.com/photo/2015/08/05/10/40/andreas-kappus-876133_960_720.jpg'),
(4, 'Claude Monet', 'https://cdn.pixabay.com/photo/2015/08/05/10/41/andreas-kaufmann-876134_960_720.jpg'),
(5, 'Frida Kahlo', 'https://cdn.pixabay.com/photo/2018/04/05/09/32/portrait-3292287_1280.jpg');

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