-- triggers

-- we need to be sure that the event that we are scheduling has the
-- number of seats that is not greater that number of seats in the
-- location that it will take place
CREATE OR REPLACE FUNCTION check_event_seats_less_than_location_seats()
RETURNS TRIGGER AS $$
DECLARE
    max_seats BIGINT;
BEGIN
    SELECT seats INTO max_seats FROM "location" WHERE id=NEW.location_id;

    IF NEW.seats > max_seats THEN
        RAISE NOTICE 'max_seats is currently %', max_seats;
        RAISE NOTICE 'seats is currently %', NEW.seats;
        RAISE EXCEPTION 'not enough seats';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_event_seats BEFORE INSERT ON "event" FOR EACH ROW EXECUTE FUNCTION check_event_seats_less_than_location_seats();


-- this trigger is invoked when ticket is inserted into database.
-- it decrements the number of seats for particular event and potentially
-- refreshes the "soon_sold_out_events" materialzied view
CREATE OR REPLACE FUNCTION decrement_seats() RETURNS TRIGGER AS $$
DECLARE
    current_seats integer;
BEGIN
  UPDATE "event"
  SET seats = seats - 1
  WHERE id = NEW.event_id AND seats > 0
  RETURNING seats INTO current_seats;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No seats available for event_id %', NEW.event_id;
  END IF;

  RAISE NOTICE 'current_seats is currently %', current_seats;
  IF current_seats < 150 THEN
    RAISE NOTICE 'refreshing materialized view';
    REFRESH MATERIALIZED VIEW soon_sold_out_events;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_decrement_seats AFTER INSERT ON "ticket" FOR EACH ROW EXECUTE FUNCTION decrement_seats();


-- ensure user that wishes to register is adult
CREATE OR REPLACE FUNCTION ensure_adult() RETURNS TRIGGER AS $$
DECLARE
  user_age INTEGER;
BEGIN
  SELECT EXTRACT(YEAR FROM AGE(CURRENT_DATE,NEW.birthdate)) :: int INTO user_age;

  IF user_age < 18 THEN
    RAISE EXCEPTION 'user (id = %) is not adult', NEW.id;
  END IF;

  NEW.registered_at := CURRENT_TIMESTAMP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_ensure_seats BEFORE INSERT ON "user" FOR EACH ROW EXECUTE FUNCTION ensure_adult();