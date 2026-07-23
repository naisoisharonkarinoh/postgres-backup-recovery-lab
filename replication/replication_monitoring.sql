-- Part F: Monitor replication health from the primary.

SELECT application_name,
       state,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- Real output captured from this lab (run against the primary on port 5546,
-- immediately after inserting a new row and confirming it appeared on the
-- standby on port 5547):
--
--  application_name |   state   | lag_bytes
-- ------------------+-----------+-----------
--  walreceiver       | streaming |         0
--
-- Recorded findings:
--   Standby name (application_name): walreceiver  (the default; the standby
--     was not given a custom application_name via primary_conninfo)
--   Replication state:               streaming
--   Replication lag:                 0 bytes (fully caught up) at the
--     moment of observation; confirmed functionally by inserting a row on
--     the primary and reading it back from the standby ~2 seconds later,
--     and by confirming the standby rejects writes
--     ("ERROR: cannot execute INSERT in a read-only transaction").
