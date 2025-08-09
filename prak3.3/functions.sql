CREATE OR REPLACE FUNCTION get_students_by_tuition (typ tuition_t, maj integer)
RETURNS refcursor
AS $get_students_by_tuition$
DECLARE
	cur refcursor;
BEGIN
	IF NOT EXISTS (SELECT 1 FROM majors WHERE majors.major_id = maj) THEN
		RAISE EXCEPTION 'Major % not found', maj;
	END IF;
	OPEN cur FOR (
		SELECT *
		FROM students JOIN majors USING (major_id)
		WHERE students.major_id = maj
			AND students.tuition_type = typ
			AND students.enrollment_year + majors.duration >= EXTRACT(YEAR FROM CURRENT_DATE)
	);
	RETURN cur;
END;
$get_students_by_tuition$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION boost_relevant_majors (ignorelist text[])
RETURNS void
AS $boost_relevant_majors$
DECLARE
	hype_subjects text[];
	s text;
BEGIN
	SELECT majors.subjects
		INTO hype_subjects
		FROM majors
		ORDER BY (free_students + paid_students) DESC, "name"
		LIMIT 1;
	FOREACH s IN ARRAY hype_subjects
	LOOP
		IF s = ANY(ignorelist) THEN
			CONTINUE;
		END IF;
		UPDATE majors
			SET free_places = free_places * 1.1
			WHERE s = ANY(subjects);
			
	END LOOP;
END;
$boost_relevant_majors$ LANGUAGE plpgsql;

SELECT *
		FROM majors
		ORDER BY (free_students + paid_students) DESC, "name"
		LIMIT 100;

SELECT boost_relevant_majors('{''Математика'', ''Статистика''}' :: text[]);

SELECT * FROM mentors LIMIT 1;

CREATE OR REPLACE FUNCTION average_mentor_experience (year_from integer, year_to integer)
RETURNS real
AS $average_mentor_experience$
BEGIN
	IF year_from > year_to THEN
		RAISE EXCEPTION 'Lower bound % must not be greater than upper bound %.', year_from, year_to;
	END IF;
	RETURN (
		SELECT avg((mentors.personal_info->'experience_years') :: int)
		FROM students
			JOIN mentors USING (mentor_id)
			JOIN majors USING (major_id)
		WHERE students.enrollment_year >= year_from
			AND students.enrollment_year + majors.duration <= year_to
	);
END;
$average_mentor_experience$ LANGUAGE plpgsql;

SELECT average_mentor_experience(2004, 2007);





CREATE OR REPLACE FUNCTION average_mentor_experience (year_from integer, year_to integer)
RETURNS real
AS $average_mentor_experience$
BEGIN
	IF year_from > year_to THEN
		RAISE EXCEPTION 'Lower bound % must not be greater than upper bound %.', year_from, year_to;
	END IF;
	RETURN (
		SELECT avg(students.enrollment_year - ((mentors.personal_info->'career_start_year') :: int))
		FROM students
			JOIN mentors USING (mentor_id)
			JOIN majors USING (major_id)
		WHERE students.enrollment_year >= year_from
			AND students.enrollment_year + majors.duration <= year_to
	);
END;
$average_mentor_experience$ LANGUAGE plpgsql;
























