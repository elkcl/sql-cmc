-- Сколько рейсов с кол-вом пассажиров > 50 вылетело из санкт петербурга с 1 по 10 января 2017 включительно
SELECT count(*)
FROM (SELECT flight_id
      FROM (flights JOIN boarding_passes USING (flight_id)) JOIN airports ON departure_airport = airport_code
      WHERE actual_departure >= '2017-01-01' AND actual_departure <= '2017-01-10' AND city = 'Санкт-Петербург'
      GROUP BY flight_id
      HAVING count(*) > 50) fls;