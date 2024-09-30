-- Список преподавателей, ведущих более одного предмета

SELECT teachers.teacher_id AS "id",
       teachers.last_name  AS last_name,
	   teachers.first_name AS first_name,
	   teachers.patronym   AS patronym,
	   count(*)            AS subj_cnt
FROM teachers
     JOIN teachings USING (teacher_id)
	 JOIN subjects  USING (subject_id)
GROUP BY "id",
         last_name,
		 first_name,
		 patronym
HAVING count(*) > 1
ORDER BY subj_cnt DESC,
         last_name,
		 first_name,
		 patronym;