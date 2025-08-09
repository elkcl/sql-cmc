-- DROP SCHEMA IF EXISTS public CASCADE;
-- CREATE SCHEMA public;

BEGIN;

CREATE TYPE tuition_t AS ENUM ('бюджет', 'контракт');

CREATE TABLE majors (
	major_id SERIAL PRIMARY KEY,
	"name" text NOT NULL,
	description text NOT NULL,
	free_places integer NOT NULL,
	paid_places integer NOT NULL,
	free_students integer NOT NULL,
	paid_students integer NOT NULL,
	subjects text[] NOT NULL,
	duration integer NOT NULL,
	CHECK (free_students <= free_places),
	CHECK (paid_students <= paid_places)
);

CREATE TABLE mentors (
	mentor_id SERIAL PRIMARY KEY,
	last_name text NOT NULL,
	first_name text NOT NULL,
	patronym text,
	personal_info jsonb NOT NULL
);

CREATE TABLE students (
	student_id SERIAL PRIMARY KEY,
	major_id integer REFERENCES majors (major_id) NOT NULL,
	mentor_id integer REFERENCES mentors (mentor_id),
	last_name text NOT NULL,
	first_name text NOT NULL,
	patronym text,
	enrollment_year integer NOT NULL,
	tuition_type tuition_t NOT NULL,
	personal_info jsonb NOT NULL
);

COPY majors
FROM '../prak3.1/majors.csv'
WITH (FORMAT csv);

COPY mentors
FROM '../prak3.1/mentors.csv'
WITH (FORMAT csv);

COPY students
FROM '../prak3.1/students.csv'
WITH (FORMAT csv);

COMMIT;