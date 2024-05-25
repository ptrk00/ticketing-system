CREATE OR REPLACE FUNCTION fib(n integer)
    RETURNS decimal(1000,0)
AS $$
    DECLARE counter integer := 0;
    DECLARE a decimal(1000,0) :=0;
    DECLARE b decimal(1000,9) :=1;
BEGIN
    IF (n < 1) THEN
        RETURN 0;
    END IF;

    LOOP
        EXIT WHEN counter = n;
        counter := counter +1;
        SELECT b,a+b INTO a,b;
    END LOOP;

    RETURN a;
END;
$$

LANGUAGE plpgsql;

SELECT fib(4);

CREATE OR REPLACE FUNCTION popularity_fun(sum numeric, seats bigint, location_id bigint) 
    RETURNS numeric
AS $$
    DECLARE location_seats integer;
BEGIN
    SELECT location.seats into location_seats from location where location.id = location_id;
    RETURN sum + (location_seats - seats) / location_seats::FLOAT8; 
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE AGGREGATE popularity(seats bigint, location_id bigint) (
    INITCOND = 0,
    STYPE = numeric,
    SFUNC = popularity_fun
);

select e.genre, popularity(e.seats, e.location_id) from event e group by e.genre;

select e.seats as available_seats, l.seats as location_seats, e.genre from event e inner join location l on e.location_id=l.id;

CREATE MATERIALIZED VIEW IF NOT EXISTS my_new_view AS
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
    -- WHERE e.seats < 150
WITH NO DATA;

REFRESH MATERIALIZED VIEW soon_sold_out_events;

SELECT * FROM soon_sold_out_events;


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

-- 
SELECT add_event(
    'Concert Night',        -- aname
    'A great music event',  -- adescription
    'sport',                -- agenre
    '2024-06-15',           -- astart_date
    '2024-06-16',           -- aend_date
    100,                    -- aseats
    1,                      -- alocation_id
    1, 2, 3                 -- variadic artist IDs
);