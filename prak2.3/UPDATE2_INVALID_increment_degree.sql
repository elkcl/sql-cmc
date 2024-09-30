-- Повысить степень всех направлений факультета id=5 с длительностью не менее 5 лет

UPDATE majors
SET "degree" = next_degree("degree")
WHERE department_id = 5 AND duration >= 5
AND degree < 'кандидат'
;

SELECT *
FROM majors
WHERE department_id = 5 AND duration >= 5;