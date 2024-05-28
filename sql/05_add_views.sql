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

CREATE VIEW location_details AS
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
