-- Средняя стоимость билета для каждого пассажира, округленная до 2х знаков после запятой

SELECT passenger_name, trunc(avg(tot), 2)
FROM (SELECT ticket_no, passenger_name, sum(amount) AS tot
      FROM tickets ts JOIN ticket_flights tfl USING (ticket_no)
	  GROUP BY ticket_no, passenger_name) AS sums
GROUP BY passenger_name
ORDER BY passenger_name;