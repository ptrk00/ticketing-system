-- This function adds event, it takes all args that are needed to crate event
-- record itself and also arbitrary len of artists ids. 
CREATE OR REPLACE FUNCTION add_event(aname varchar(255), adescription varchar(255), agenre varchar(10), 
    astart_date date, aend_date date, aseats bigint, alocation_id bigint, 
    along_description varchar(2048), abase_prize numeric(12,2), abase_prize_currency varchar(3), 
    aimage_url varchar(255), VARIADIC aartists BIGINT[]) RETURNS BIGINT
AS $$
DECLARE
    event_id bigint;
    aartist bigint;
BEGIN
    INSERT INTO event(name, description, genre, start_date, end_date, seats, location_id, long_description, base_price, base_price_currency, image_url) VALUES (
        aname, adescription, agenre, astart_date, aend_date, aseats, alocation_id, along_description, abase_prize, abase_prize_currency, aimage_url
    ) RETURNING id into event_id;

    FOREACH aartist IN ARRAY aartists
    LOOP
        INSERT INTO event_artist(event_id,artist_id) VALUES(event_id, aartist);
    END LOOP;
    RETURN event_id;
END;
$$LANGUAGE plpgsql;

-- revoke event
CREATE OR REPLACE FUNCTION revoke_event(aevent_id bigint) RETURNS VOID
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

-- delete location
CREATE OR REPLACE FUNCTION delete_location(alocation_id bigint) RETURNS VOID
AS $$
BEGIN
    PERFORM revoke_event(e.id) FROM event e WHERE e.location_id=alocation_id;
    DELETE FROM location WHERE id=alocation_id;
END;
$$LANGUAGE plpgsql;

-- compute the price of the ticket for given event
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
    RETURN QUERY (
        SELECT 
            ROUND(e_base_price + ((e_seats_capacity-e_seats)/e_seats_capacity::NUMERIC * e_base_price), 2) as price, 
            currency AS currency);
END;
$$ LANGUAGE plpgsql;

-- buy ticket
CREATE OR REPLACE FUNCTION buy_ticket(user_id bigint, event_id bigint) RETURNS void 
AS $$
DECLARE
    ticket_currency varchar(3);
    ticket_cost numeric;
    current_seats INTEGER;
BEGIN
 
 SELECT price, currency from ticket_prize(event_id) into ticket_cost, ticket_currency;
 
 INSERT INTO ticket (owner_id, event_id, price, currency, bought_at) 
    VALUES (user_id, event_id, ticket_cost, ticket_currency, current_timestamp);
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