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