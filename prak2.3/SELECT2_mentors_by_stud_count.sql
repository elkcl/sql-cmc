-- Научные руководители, отсортированные по кол-ву их студентов

SELECT teachers.teacher_id,
       teachers.last_name,
	   teachers.first_name,
	   teachers.patronym,
	   count(*)              AS student_count
FROM teachers
     JOIN enrollments ON enrollments.mentor_id = teachers.teacher_id
GROUP BY teachers.teacher_id, 
         teachers.last_name,
		 teachers.first_name,
		 teachers.patronym
ORDER BY student_count DESC,
         teachers.last_name,
		 teachers.first_name,
		 teachers.patronym,
		 teachers.teacher_id;