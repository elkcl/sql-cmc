-- Аэропорты, из которых задерживались рейсы более чем на час, и в которые задерживались
-- взлёты более чем на час

SELECT airport_code, city
FROM flights JOIN airports ON departure_airport = airport_code
WHERE EXTRACT(EPOCH FROM actual_departure - scheduled_departure) > 3600
INTERSECT
SELECT airport_code, city
FROM flights JOIN airports ON arrival_airport = airport_code
WHERE EXTRACT(EPOCH FROM actual_arrival - scheduled_arrival) > 3600
ORDER BY airport_code;