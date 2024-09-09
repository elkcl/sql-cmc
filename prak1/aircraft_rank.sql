-- По каждому аэропорту с буквы Б вывести самолёты, оттуда вылетающие,
-- и проранжировать по тому, сколько раз вылетали

SELECT airport_name, 
       aircraft_code, 
	   count(*) as cnt, 
	   rank() OVER 
	       (PARTITION BY airport_name ORDER BY count(*) DESC)
FROM (flights JOIN aircrafts USING (aircraft_code)) fl 
      JOIN airports ap ON fl.departure_airport = ap.airport_code
GROUP BY airport_name, aircraft_code
HAVING airport_name LIKE 'Б%'
ORDER BY airport_name, cnt DESC, aircraft_code;