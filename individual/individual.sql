CREATE FUNCTION status_key(varchar(20)) RETURNS int AS $status_key$
SELECT array_position(ARRAY['Scheduled',
	                        'On Time',
	                        'Delayed', 
                            'Departed',
                            'Arrived',
                            'Cancelled']::varchar(20)[], $1);
$status_key$ LANGUAGE sql;

CREATE FUNCTION status_new_key(varchar(20)) RETURNS int AS $status_new_key$
SELECT array_position(ARRAY['Scheduled',
	                        'Check-In',
	                        'Boarding', 
                            'Boarding Closed',
                            'Departed',
                            'Arrived',
                            'Cancelled']::varchar(20)[], $1);
$status_new_key$ LANGUAGE sql;

CREATE FUNCTION delayed_new_key(varchar(20)) RETURNS int AS $delayed_new_key$
SELECT array_position(ARRAY['On Time',
	                        'Delayed']::varchar(20)[], $1);
$delayed_new_key$ LANGUAGE sql;

CREATE VIEW bookings.flights_view AS
  SELECT flight_id, 
         flight_no, 
	     scheduled_departure, 
	     scheduled_arrival,
	     departure_airport,
	     arrival_airport,
	     status,
	     aircraft_code,
	     actual_departure,
	     actual_arrival
  FROM bookings.flights;

BEGIN;
ALTER TABLE bookings.flights RENAME TO flights_data;
ALTER TABLE bookings.flights_view RENAME TO flights;
COMMIT;

CREATE FUNCTION bookings.flights_update() RETURNS TRIGGER AS $flights_update$
  BEGIN
    UPDATE bookings.flights_data
      SET flight_no = NEW.flight_no,
	      scheduled_departure = NEW.scheduled_departure, 
	      scheduled_arrival = NEW.scheduled_arrival,
	      departure_airport = NEW.departure_airport,
	      arrival_airport = NEW.arrival_airport,
	      aircraft_code = NEW.aircraft_code,
	      actual_departure = NEW.actual_departure,
	      actual_arrival = NEW.actual_arrival
	  WHERE flight_id = NEW.flight_id;
    IF ((SELECT status FROM bookings.flights_data WHERE flight_id = NEW.flight_id) != NEW.status) THEN
      UPDATE bookings.flights_data
	    SET status = NEW.status,
	        status_new = NULL,
		    delayed_new = NULL
		WHERE flight_id = NEW.flight_id;
    END IF;
	RETURN NEW;
  END;
$flights_update$ LANGUAGE plpgsql;

BEGIN;
ALTER TABLE bookings.flights_data
  ADD status_new varchar(20)
    CHECK (status_new IN ('Scheduled',
	                      'Check-In',
	                      'Boarding', 
                          'Boarding Closed',
                          'Departed',
                          'Arrived',
                          'Cancelled') OR status_new IS NULL);
ALTER TABLE bookings.flights_data
  ADD delayed_new varchar(20)
    CHECK (delayed_new IN ('On Time',
	                       'Delayed') OR delayed_new IS NULL);
ALTER TABLE bookings.flights_data
  ADD CHECK (((status_new IS NULL) AND (delayed_new IS NULL)) OR 
              (status_new IS NOT NULL) AND (delayed_new IS NOT NULL)) NOT VALID;
CREATE TRIGGER flights_update_trig
  INSTEAD OF UPDATE
  ON bookings.flights
  FOR EACH ROW EXECUTE FUNCTION bookings.flights_update();
COMMIT;

-- CREATE VIEW flights_new AS
--   SELECT flight_id, 
--          flight_no, 
-- 	     scheduled_departure, 
-- 	     scheduled_arrival,
-- 	     departure_airport,
-- 	     arrival_airport,
-- 	     (
--            CASE WHEN (status_new IS NULL) OR (delayed_new IS NULL) THEN status
-- 		        WHEN status_new IN ('Scheduled', 'Departed', 'Arrived', 'Cancelled') THEN status_new
-- 				ELSE delayed_new
-- 			END
-- 		 ),
-- 	     aircraft_code,
-- 	     actual_departure,
-- 	     actual_arrival
--   FROM bookings.flights_data;

-- CREATE FUNCTION bookings.flights_update() RETURNS TRIGGER AS $flights_update$
--   BEGIN
--     IF (TG_OP = 'DELETE') THEN
--       DELETE FROM bookings.flights_data WHERE flight_id = OLD.flight_id;
--     ELSIF (TG_OP = 'INSERT') THEN
--       INSERT INTO bookings.flights_data VALUES(NEW.*, NULL, NULL);
--     ELSIF (TG_OP = 'UPDATE') THEN
--       UPDATE bookings.flights_data
--       SET flight_id = NEW.flight_id,
--           flight_no = NEW.flight_no,
-- 	      scheduled_departure = NEW.scheduled_departure, 
-- 	      scheduled_arrival = NEW.scheduled_arrival,
-- 	      departure_airport = NEW.departure_airport,
-- 	      arrival_airport = NEW.arrival_airport,
-- 	      aircraft_code = NEW.aircraft_code,
-- 	      actual_departure = NEW.actual_departure,
-- 	      actual_arrival = NEW.actual_arrival;
--       IF (status != NEW.status) THEN
--         UPDATE bookings.flights_data
-- 	    SET status = NEW.status,
-- 	        status_new = NULL,
-- 		    delayed_new = NULL;
--       END IF;
--     END IF;
--   END;
-- $flights_update$ LANGUAGE plpgsql;

-- BEGIN;
-- ALTER TABLE bookings.flights RENAME TO bookings.flights_old;
-- ALTER TABLE bookings.flights_new RENAME TO bookings.flights;
-- COMMIT;

-- DROP VIEW bookings.flights_old;

CREATE TABLE bookings.status_history (
  flight_id integer REFERENCES flights_data(flight_id),
  status varchar(20) NOT NULL,
  status_new varchar(20),
  delayed_new varchar(20),
  change_time timestamptz,
  PRIMARY KEY (flight_id, change_time),
  CHECK (status IN ('Scheduled',
	                'On Time',
	                'Delayed', 
                    'Departed',
                    'Arrived',
                    'Cancelled')),
  CHECK (status_new IN ('Scheduled',
	                    'Check-In',
	                    'Boarding', 
                        'Boarding Closed',
                        'Departed',
                        'Arrived',
                        'Cancelled') OR status_new IS NULL),
  CHECK (delayed_new IN ('On Time',
	                     'Delayed') OR delayed_new IS NULL),
  CHECK (((status_new IS NULL) AND (delayed_new IS NULL)) OR 
              (status_new IS NOT NULL) AND (delayed_new IS NOT NULL))
);

CREATE FUNCTION bookings.log_status_history() RETURNS TRIGGER AS $log_status_history$
  BEGIN
    INSERT INTO bookings.status_history
	SELECT DISTINCT ON (flight_id) flight_id, status, status_new, delayed_new, current_timestamp
	FROM new_tbl
	ORDER BY flight_id,
	         status_key(status) DESC NULLS LAST,
	         status_new_key(status_new) DESC NULLS LAST,
			 delayed_new_key(delayed_new) DESC NULLS LAST
	ON CONFLICT (flight_id, change_time) DO UPDATE SET
	  status = EXCLUDED.status,
	  status_new = EXCLUDED.status_new,
	  delayed_new = EXCLUDED.delayed_new;
	RETURN NULL;
  END;
$log_status_history$ LANGUAGE plpgsql;

CREATE TRIGGER log_status_history_insert_trig
  AFTER INSERT
  ON bookings.flights_data
  REFERENCING NEW TABLE as new_tbl
  FOR EACH STATEMENT EXECUTE FUNCTION bookings.log_status_history();

CREATE TRIGGER log_status_history_update_trig
  AFTER UPDATE
  ON bookings.flights_data
  REFERENCING NEW TABLE as new_tbl
  FOR EACH STATEMENT EXECUTE FUNCTION bookings.log_status_history();
