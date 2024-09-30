-- Увеличить кол-во бюджетных мест на 10% на всех направлениях, 
-- где платников больше чем в два раза больше бюджетников

UPDATE majors
SET free_places = free_places * 1.10
WHERE major_id IN (
  SELECT major_id
  FROM majors
       JOIN "groups"    USING (major_id)
	   JOIN enrollments USING (group_id)
  GROUP BY major_id
  HAVING (count(*) FILTER (WHERE tuition_type = 'контракт')) 
           > 2 * (count(*) FILTER (WHERE tuition_type = 'бюджет'))
);

SELECT major_id,
       count(*) FILTER (WHERE tuition_type = 'контракт') AS paid,
	   count(*) FILTER (WHERE tuition_type = 'бюджет')   AS "free",
	   paid_places,
	   free_places
  FROM majors
       JOIN "groups"    USING (major_id)
	   JOIN enrollments USING (group_id)
  GROUP BY major_id, paid_places, free_places
  ORDER BY major_id;

