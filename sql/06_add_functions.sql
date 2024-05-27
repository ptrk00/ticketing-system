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