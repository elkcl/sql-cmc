UPDATE management_majors
SET free_places = free_places * 1.1
WHERE 'Маркетинг' = ANY(subjects);

UPDATE majors
SET free_places = free_places * 1.1
WHERE 'Маркетинг' = ANY(subjects);

UPDATE management_majors
SET description = 'jgoknogns'
WHERE 'Маркетинг' = ANY(subjects);

INSERT INTO majors VALUES (1000001, 'iohoj', 10, 10, 5, 5, '{}'::text[], 4, 'hhiih');

UPDATE management_majors
SET subjects = '{}'::text[]
WHERE major_id = 23191;

SELECT * FROM management_majors LIMIT 5;