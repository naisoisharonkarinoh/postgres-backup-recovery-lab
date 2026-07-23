-- Part C: Disaster simulation
-- Run against the "lab" database, "students" table (5 rows, seeded before
-- the base backup in wal_archiving/base_backup_commands.sh was taken).

-- 1. Capture the current time BEFORE the disaster -- this is the moment we
--    will later recover to.
SELECT now();
-- Recorded value: 2026-07-23 16:45:11.968961+03

-- (Row count immediately before the delete, for reference)
SELECT count(*) FROM students;
-- Recorded value: 5

-- 2. Simulate the disaster: an accidental full-table delete.
DELETE FROM students;
-- Recorded output: DELETE 5

-- 3. Force the current WAL segment to close so the DELETE is archived
--    immediately rather than waiting for it to fill naturally (only needed
--    because this is a low-traffic lab database).
SELECT pg_switch_wal();
