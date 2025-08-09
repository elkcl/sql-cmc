SELECT * FROM bookings.status_history;

SELECT * FROM flights ORDER BY flight_id LIMIT 5;

UPDATE bookings.flights
SET status = 'Delayed'
WHERE flight_id = 4;