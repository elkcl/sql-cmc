-- Удалить преподавателей с ФИО "Анисимова Арина Фёдоровна" из базы

DROP TABLE IF EXISTS target_id;
SELECT teacher_id
INTO target_id
FROM teachers
WHERE last_name = 'Анисимова' AND first_name = 'Арина' AND patronym = 'Фёдоровна';

DELETE FROM teachings
WHERE teacher_id IN (SELECT * FROM target_id);

UPDATE enrollments
SET mentor_id = (
  SELECT teacher_id
  FROM teachers
  WHERE last_name = 'Анохина' AND first_name = 'Анна' AND patronym = 'Львовна'
)
WHERE mentor_id IN (SELECT * FROM target_id);

DELETE FROM teachers
WHERE teacher_id IN (SELECT * FROM target_id);