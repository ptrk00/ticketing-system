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

-- custom aggregate function for computing popularity based on no of seats already taken
-- function invoked for every record
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

-- function evaluated once at the end, we need to divide the accumulated
-- popularity by the number of records processed
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

-- actual aggregate function
CREATE OR REPLACE AGGREGATE popularity(seats bigint, seats_capacity bigint) (
    INITCOND = '{0,0}',
    STYPE = numeric[],
    SFUNC = popularity_fun,
    FINALFUNC = popularity_final
);