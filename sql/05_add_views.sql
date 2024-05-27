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