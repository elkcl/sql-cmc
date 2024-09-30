-- Все предметы студентов с ФИО "Самсонов Александр Никитич"

SELECT students.student_id,
       majors."name"    AS major,
       subjects.name    AS subject,
	   subjects.credits
FROM subjects 
     JOIN studies     USING (subject_id)
	 JOIN "groups"    USING (group_id)
	 JOIN enrollments USING (group_id)
	 JOIN students    USING (student_id)
	 JOIN majors      USING (major_id)
WHERE students.last_name = 'Самсонов'
      AND students.first_name = 'Александр'
	  AND students.patronym = 'Никитич'
ORDER BY students.student_id,
         major,
		 subject,
		 subjects.credits DESC;