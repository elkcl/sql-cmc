BEGIN;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM test;
REVOKE ALL PRIVILEGES ON SCHEMA public FROM test;
REVOKE ALL PRIVILEGES ON DATABASE "dean-stats" FROM test;
DROP USER IF EXISTS test;

CREATE USER test;
GRANT CONNECT ON DATABASE "dean-stats" TO test;
GRANT USAGE ON SCHEMA public TO test;
GRANT SELECT, UPDATE, INSERT ON TABLE students TO test;
GRANT SELECT, UPDATE (personal_info) ON TABLE mentors TO test;
GRANT SELECT ON TABLE majors TO test;
COMMIT;

DROP VIEW IF EXISTS current_transition_candidates;
CREATE VIEW current_transition_candidates AS
	SELECT student_id, major_id, last_name, first_name, patronym, personal_info
	FROM students JOIN majors USING (major_id)
	WHERE students.enrollment_year + majors.duration >= EXTRACT(YEAR FROM CURRENT_DATE)
	      AND students.tuition_type = 'контракт'
		  AND majors.free_students < majors.free_places;
GRANT SELECT ON TABLE current_transition_candidates TO test;

DROP VIEW IF EXISTS management_majors;
CREATE VIEW management_majors AS
    SELECT *
	FROM majors
	WHERE 'Менеджмент' = ANY(majors.subjects);

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM management_dean;
DROP ROLE IF EXISTS management_dean;

CREATE ROLE management_dean;
GRANT SELECT, UPDATE (free_places, paid_places) ON TABLE management_majors TO management_dean;
GRANT management_dean TO test;