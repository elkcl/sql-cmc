EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM students
WHERE tuition_type = 'бюджет'
	AND enrollment_year >= EXTRACT(YEAR FROM CURRENT_DATE) - 1
	AND (personal_info->'birthday'->'month') :: int = 12;


EXPLAIN (ANALYZE, BUFFERS)
SELECT students.last_name, students.first_name, majors.name, majors.subjects, majors.description
FROM students JOIN majors ON majors.major_id = students.major_id
WHERE students.tuition_type = 'контракт'
	AND majors.subjects @> '{"Менеджмент", "Математика"}'
	AND to_tsquery('simple', 'est & ad') @@ to_tsvector('simple', majors.description)
ORDER BY students.student_id;

CREATE INDEX students_enrollment_year_index ON students (enrollment_year);
CREATE INDEX students_tuition_type_index ON students (tuition_type);
CREATE INDEX students_birthday_month_index ON students (((personal_info->'birthday'->'month') :: int));

CREATE INDEX majors_subjects_index ON majors USING GIN (subjects);
CREATE INDEX majors_description_index ON majors USING GIN ((to_tsvector('simple', description)));

DROP INDEX IF EXISTS students_enrollment_year_index;
DROP INDEX IF EXISTS students_tuition_type_index;
DROP INDEX IF EXISTS students_birthday_month_index;

DROP INDEX IF EXISTS majors_subjects_index;
DROP INDEX IF EXISTS majors_description_index;