-- Увеличить кол-во бюджетных мест на всех направленияя факультета с id=4 на 10%

UPDATE majors
SET free_places = free_places * 1.10
WHERE department_id = 4;

SELECT *
FROM majors
WHERE department_id = 4;