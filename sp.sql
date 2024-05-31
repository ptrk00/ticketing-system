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

CREATE OR REPLACE FUNCTION popularity_fun(state numeric[], seats bigint, seats_capacity bigint) 
RETURNS numeric[]
AS $$
BEGIN
    state[1] := state[1] + ((seats_capacity::FLOAT8 - seats::numeric) / seats_capacity::FLOAT8);
    state[2] := state[2] + 1;
    RETURN state;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION popularity_final(state numeric[])
RETURNS numeric AS $$
BEGIN
    IF state[2] = 0 THEN
        RETURN 0; -- handle case with no rows processed
    END IF;
    RAISE NOTICE 'accumulated val: %, records processed: %', state[1], state[2];
    RETURN state[1] / state[2];
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE AGGREGATE popularity(seats bigint, seats_capacity bigint) (
    INITCOND = '{0,0}',
    STYPE = numeric[],
    SFUNC = popularity_fun,
    FINALFUNC = popularity_final
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


CREATE OR REPLACE VIEW event_details AS 
    SELECT 
        event.id, 
        event.name,
        event.image_url as image_url,
        description, 
        start_date, 
        end_date, 
        event.seats as "seats_left", 
        location.name as "location_name" 
    FROM "event" 
        INNER JOIN location ON event.location_id = location.id;

CREATE RULE revoke_instead_of_delete_ticket AS 
    ON DELETE TO ticket
        DO INSTEAD
            UPDATE ticket SET revoked = TRUE WHERE id = OLD.id;


CREATE OR REPLACE FUNCTION ticket_prize(event_id bigint) 
    RETURNS TABLE (
        price numeric,
        currency varchar(3)
    )
AS $$
DECLARE
    e_base_price bigint;
    e_seats bigint;
    e_seats_capacity bigint;
    currency varchar(3);
BEGIN
    SELECT base_price, base_price_currency, seats, seats_capacity into e_base_price, currency, e_seats, e_seats_capacity FROM event where id = event_id;
    RETURN QUERY (e_base_price + ((e_seats_capacity-e_seats)/e_seats_capacity::FLOAT8 * e_base_price), base_price_currency);
END;
$$ LANGUAGE plpgsql;

select e.name, e.genre, popularity(e.seats, e.seats_capacity) over (partition by e.genre) from event e;


CREATE OR REPLACE FUNCTION revoked_event(aevent_id bigint) RETURNS VOID
AS $$
DECLARE
current_seats INTEGER;
BEGIN
    -- revoke all tickets for that event 
    UPDATE ticket SET revoked=TRUE where ticket.event_id = aevent_id;

    -- remove from event_artists 
    DELETE FROM event_artist WHERE event_artist.event_id = aevent_id;

    -- finally revoke event
    UPDATE event SET revoked=TRUE WHERE id=aevent_id RETURNING seats INTO current_seats;

    -- check if we need to refresh materialized view 
    IF current_seats < 150 THEN
        RAISE NOTICE 'refreshing materialized view';
        REFRESH MATERIALIZED VIEW soon_sold_out_events;
    END IF;
END;
$$LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_location(alocation_id bigint) RETURNS VOID
AS $$
BEGIN
    PERFORM revoke_event(e.id) FROM event e WHERE e.location_id=alocation_id;
    DELETE FROM location WHERE id=alocation_id;
END;
$$LANGUAGE plpgsql;