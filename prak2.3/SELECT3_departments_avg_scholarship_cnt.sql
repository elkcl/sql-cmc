-- Факультет - Направление - Кол-во бюджетников на направлении - Среднее кол-во бюджетников по факультету

SELECT departments.department_id                                             AS department_id, 
       departments."name"                                                    AS department,
	   majors.major_id                                                       AS major_id,
	   majors."name"                                                         AS major,
	   count(*)                                                              AS cnt, 
	   trunc(avg(count(*)) OVER (PARTITION BY departments.department_id), 2) AS avg_cnt
FROM departments
     JOIN majors      USING (department_id)
	 JOIN "groups"    USING (major_id)
	 JOIN enrollments 
	   ON (enrollments.group_id = "groups".group_id AND enrollments.tuition_type = 'бюджет')
GROUP BY department_id,
         department,
		 major_id,
		 major
ORDER BY department_id,
         major_id,
		 cnt DESC;