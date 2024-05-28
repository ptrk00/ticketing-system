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

-- views for querying location
CREATE OR REPLACE VIEW location_overview AS 
    SELECT 
        id, 
        name, 
        seats as max_seats,
        image_url,
        description, 
        coordinates
    FROM "location"; 

CREATE OR REPLACE VIEW location_details AS
    SELECT 
        location.id, 
        location.name,
        location.image_url, 
        location.seats AS max_seats, 
        ST_Y(ST_AsText(location.coordinates::geometry)) AS latitude,
        ST_X(ST_AsText(location.coordinates::geometry)) AS longitude,
        location.description,
        closest_event.name AS closest_event_name,
        closest_event.start_date AS closest_event_start_date,
        closest_event.seats AS closest_event_seats_left,
        closest_event.image_url AS closest_event_image_url,
        closest_event.description AS closest_event_description,
        closest_event.id AS closest_event_id
    FROM 
        location
    LEFT JOIN LATERAL (
        SELECT 
            event.id,
            event.name,
            event.start_date,
            event.seats,
            event.image_url,
            event.description
        FROM 
            event
        WHERE 
            event.location_id = location.id
            AND current_date < event.start_date
        ORDER BY 
            event.start_date ASC
        LIMIT 1
    ) closest_event ON true;

-- views for querying actors
CREATE OR REPLACE VIEW artist_overview AS
    SELECT 
        artist.id, 
        artist.name,
        artist.image_url
    FROM "artist"; 

CREATE OR REPLACE VIEW artist_details AS
    SELECT 
        artist.id AS artist_id,
        artist.name,
        artist.image_url,
        json_agg(json_build_object('event_id', event.id, 'event_name', event.name)) AS events
    FROM 
        artist
    INNER JOIN 
        event_artist ON event_artist.artist_id = artist.id
    INNER JOIN 
        event ON event_artist.event_id = event.id
    GROUP BY 
        artist.id, artist.name, artist.image_url;

-- views for tickets
CREATE OR REPLACE VIEW ticket_overview AS
    SELECT 
        ticket.id,
        event.name as event,
        "user".id as owner_id,
        "user".name as owner_name,
        "user".email as owner_email,
        price,
        currency
    FROM "ticket"
    INNER JOIN "user" ON ticket.owner_id="user".id
    INNER JOIN "event" ON ticket.event_id=event.id; 

CREATE OR REPLACE VIEW ticket_details AS
    SELECT 
        ticket.id,
        event.name as event,
        event.start_date as event_start_date,
        "user".id as owner_id,
        "user".name as owner_name,
        "user".email as owner_email,
        price,
        currency,
        bought_at,
        revoked,
        location.name as location_name
    FROM "ticket"
        INNER JOIN "user" ON ticket.owner_id="user".id
        INNER JOIN "event" ON ticket.event_id=event.id 
        INNER JOIN "location" ON event.location_id=location.id;

-- views for user
CREATE OR REPLACE VIEW user_overview AS
    SELECT 
        id,
        name,
        email
    FROM "user";

CREATE OR REPLACE VIEW user_details AS
    SELECT 
        id, 
        name,
        email,
        birthdate,
        registered_at
    FROM "user"; 