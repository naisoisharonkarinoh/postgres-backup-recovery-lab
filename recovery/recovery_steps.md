# Point-in-Time Recovery (PITR) Steps

This documents the complete, real PITR process performed for this lab: a
`DELETE FROM students` (see `recovery/disaster_simulation.sql`) was
recovered from, restoring all 5 rows using the base backup from
`wal_archiving/base_backup_commands.sh` plus archived WAL.

## 1. Stop PostgreSQL

```bash
pg_ctl -D ~/pgdata stop -m fast
```

Real output from this lab:
```
waiting for server to shut down.... done
server stopped
```

## 2. Restore the Base Backup

Extract the base backup taken earlier into a clean data directory (never
recover on top of the live data directory):

```bash
mkdir -p ~/pitr_data
tar -xzf ~/backups/base/base.tar.gz -C ~/pitr_data
mkdir -p ~/pitr_data/pg_wal
tar -xzf ~/backups/base/pg_wal.tar.gz -C ~/pitr_data/pg_wal
```

## 3. Configure the Restore Command

In `~/pitr_data/postgresql.conf`:

```
restore_command = 'cp ~/backups/wal/%f %p'
```

(This lab's actual, Windows-adapted command — see `wal_archiving/wal_setup.md`
for why — was:
`restore_command = '"C:/Program Files/Git/usr/bin/cp.exe" "C:/Users/naiso/AppData/Local/Temp/pg-sandbox/wal_archive/%f" %p'`)

## 4. Set the Recovery Target Time

Also in `postgresql.conf`, using the timestamp captured in
`recovery/disaster_simulation.sql` **before** the `DELETE`:

```
recovery_target_time = '2026-07-23 16:45:11.968961+03'
recovery_target_action = 'promote'
```

`recovery_target_action = 'promote'` makes the server automatically come up
writable as soon as it reaches the target, instead of pausing.

## 5. Create the Recovery Signal File

PostgreSQL only enters archive recovery mode if this file is present:

```bash
touch ~/pitr_data/recovery.signal
```

## 6. Restart PostgreSQL (Pointed at the Restored Data Directory)

```bash
pg_ctl -D ~/pitr_data -l pitr_recovery.log start
```

Real log output from this lab (`pitr_recovery.log`):

```
starting PostgreSQL 18.4 on x86_64-windows...
database system was interrupted; last known up at 2026-07-23 16:43:50 EAT
starting backup recovery with redo LSN 0/60000D8, checkpoint LSN 0/6000130, on timeline ID 1
restored log file "000000010000000000000006" from archive
starting point-in-time recovery to 2026-07-23 16:45:11.968961+03
redo starts at 0/60000D8
completed backup recovery with redo LSN 0/60000D8 and end LSN 0/60001D0
consistent recovery state reached at 0/60001D0
database system is ready to accept read-only connections
restored log file "000000010000000000000007" from archive
recovery stopping before commit of transaction 766, time 2026-07-23 16:45:21.725931+03
redo done at 0/7000338
selected new timeline ID: 2
archive recovery complete
database system is ready to accept connections
```

The key line is **"recovery stopping before commit of transaction 766"** —
PostgreSQL replayed WAL up to, but not including, the `DELETE FROM students`
transaction, then stopped exactly at the requested `recovery_target_time`
and promoted onto a new timeline (timeline 2).

## 7. Verify Data Recovery

```sql
SELECT count(*) FROM students;
```

Real output:
```
 count
-------
     5
```

All 5 rows were present again, matching the pre-disaster count. Full
verification detail (including the actual restored row data) is in
`recovery/recovery_verification.md`.
