CREATE EXTENSION Postgis;

CREATE TABLE IF NOT EXISTS "ticket" (
    "id"        BIGSERIAL NOT NULL PRIMARY KEY,
    "owner_id"  BIGINT NOT NULL,
    "event_id"  BIGINT NOT NULL,
    "price"     NUMERIC(12,2) CHECK(price > 0),
    "currency"  VARCHAR(3) CHECK (currency IN ('PLN', 'USD', 'EUR', 'GBP')),
    "bought_at" TIMESTAMPTZ NOT NULL,
    "revoked"   BOOLEAN DEFAULT FALSE NOT NULL
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
    "seats_capacity"        BIGINT NOT NULL CHECK(seats_capacity > 0),             
    "seats"                 BIGINT NOT NULL CHECK(seats > 0), 
    "base_price"            NUMERIC(12,2) CHECK(base_price > 0),
    "base_price_currency"   VARCHAR(3) CHECK (base_price_currency IN ('PLN', 'USD', 'EUR', 'GBP')),
    "location_id"           BIGINT NOT NULL,
    "image_url"             VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS "user" (
    "id"        BIGINT NOT NULL PRIMARY KEY,
    "name"      VARCHAR(255) NOT NULL CHECK(LENGTH(TRIM(name)) >= 3),
    "email"     VARCHAR(255) NOT NULL UNIQUE CHECK(LENGTH(TRIM(email)) >= 3),
    "birthdate" DATE NOT NULL,
    "registered_at" TIMESTAMPTZ NOT NULL
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

-- for text search
ALTER TABLE "event" ADD COLUMN ts tsvector
    GENERATED ALWAYS AS (to_tsvector('english', description)) STORED;