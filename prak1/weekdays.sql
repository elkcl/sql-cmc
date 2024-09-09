-- Кол-во долетевших рейсов по дням недели (по времени вылета) за какой-то год
SELECT ('{Понедельник,Вторник,Среда,Четверг,Пятница,Суббота,Воскресенье}'::text[])[EXTRACT(isodow FROM actual_departure)], count(*)
FROM flights
WHERE status = 'Arrived' AND actual_departure >= '2017-01-01' AND actual_departure <= '2017-12-31'
GROUP BY EXTRACT(isodow FROM actual_departure)
ORDER BY EXTRACT(isodow FROM actual_departure);