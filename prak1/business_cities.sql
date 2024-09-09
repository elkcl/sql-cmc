-- Города, в которые летают бизнес-классом, по убыванию кол-ва бизнес-рейсов

SELECT ap.city, count(*) AS cnt
FROM (SELECT flights.arrival_airport
	FROM flights JOIN ticket_flights USING (flight_id)
	WHERE ticket_flights.fare_conditions = 'Business') AS arr 
	JOIN airports ap 
	ON arr.arrival_airport = ap.airport_code
	GROUP BY ap.city
	ORDER BY cnt DESC;