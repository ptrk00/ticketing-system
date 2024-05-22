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

select e.seats, l.seats, e.genre from event e inner join location l on e.location_id=l.id;