BEGIN ISOLATION LEVEL READ UNCOMMITTED;
UPDATE majors
SET free_places = free_places + 10
WHERE major_id = 1
RETURNING *;
SELECT pg_sleep_for('5 seconds');
ROLLBACK;
COMMIT;