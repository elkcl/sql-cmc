DROP TABLE IF EXISTS maj_desc;

CREATE TABLE maj_desc (
    major_id integer,
	description text
);

COPY maj_desc
FROM '../prak3.1/maj_desc.csv'
WITH (FORMAT csv);

ALTER TABLE majors ADD COLUMN description text;

UPDATE majors
SET description = maj_desc.description
FROM maj_desc
WHERE majors.major_id = maj_desc.major_id;

SELECT * FROM maj_desc;

SELECT * FROM majors LIMIT 10;