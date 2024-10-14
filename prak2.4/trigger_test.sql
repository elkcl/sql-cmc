-- BEGIN;
-- UPDATE majors
-- SET free_places = 200
-- WHERE major_id = 2;

-- UPDATE majors
-- SET free_places = 0
-- WHERE major_id = 1;
-- COMMIT;

SELECT *
FROM majors
ORDER BY major_id;