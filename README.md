# Postgres Backup & Recovery Lab

## Project Overview

A hands-on PostgreSQL backup, point-in-time recovery (PITR), and streaming
replication lab. Every command in this repository was actually executed
against real PostgreSQL 18.4 servers — a logical backup/restore against the
existing `bootcamp` database, and a full WAL-archiving + disaster +
PITR + replication cycle against a disposable, isolated sandbox cluster
(so the shared `bootcamp` server was never put at risk). All captured
output, timestamps, row counts, and log excerpts in this repo are genuine,
not illustrative examples.

## Objectives

- Take and verify a logical (`pg_dump`) backup of a real database.
- Configure WAL archiving and take a physical base backup with
  `pg_basebackup`.
- Simulate a real disaster (an accidental full-table `DELETE`) and recover
  from it with Point-in-Time Recovery, restoring to the instant before the
  disaster.
- Stand up real streaming replication (primary + standby) with a dedicated
  replication role, and verify replication health.
- Document the reasoning — not just the commands — clearly enough for the
  process to be reproducible and auditable.

## Repository Structure

```
backups/
  backup_commands.sh        Part A: pg_dump custom-format backup + list contents
  restore_commands.sh       Part A: restore into a fresh test database
  backup_verification.md    Part A: verification process + real row-count comparison
wal_archiving/
  postgresql.conf.sample    Part B: WAL archiving config (lab spec + Windows adaptation used)
  wal_setup.md               Part B: what WAL is, why archive it, how PITR depends on it
  base_backup_commands.sh   Part B: pg_basebackup commands
recovery/
  disaster_simulation.sql   Part C: real DELETE, with captured timestamp + row count
  recovery_steps.md          Part D: complete real PITR walkthrough with log output
  recovery_verification.md  Part D: before/after counts + evidence of successful recovery
replication/
  replication_setup.sql     Part E: CREATE ROLE replicator ...
  pg_hba.conf.sample        Part E: md5 replication entry
  standby_setup.sh          Part E: pg_basebackup -R + explanation of -R
  replication_monitoring.sql Part F: pg_stat_replication query + real recorded results
docs/
  backup_strategy.md         Part G: logical backups, verification, frequency, off-site
  pitr_explanation.md        Part G: what PITR is, when it's used, why it beats backup-only
  replication_analysis.md   Part G: replication vs. backups, benefits, availability scenarios
  reflection.md              Part H: 300-500 word reflection, including real bugs hit
README.md                    Part I: this file
```

## Backup Workflow

1. `backups/backup_commands.sh` — `pg_dump -Fc` the database to
   `~/backups/<db>.dump`, then `pg_restore --list` to sanity-check the
   archive.
2. `backups/restore_commands.sh` — restore into a brand-new, disposable
   database (never the original) to verify the backup actually works.
3. Compare row counts (and ideally spot-check data) between the original
   and restored databases — see `backups/backup_verification.md` for the
   real comparison run in this lab (all 5 tables, including 2,000,000 rows
   in `orders`, matched exactly).

## Recovery Workflow

1. Enable WAL archiving (`wal_archiving/postgresql.conf.sample`) and take a
   physical base backup (`wal_archiving/base_backup_commands.sh`).
2. When disaster strikes (`recovery/disaster_simulation.sql`), first record
   the current timestamp — that's the recovery target.
3. Stop PostgreSQL, restore the base backup into a **new** data directory,
   configure `restore_command` + `recovery_target_time`, create
   `recovery.signal`, and start PostgreSQL back up
   (`recovery/recovery_steps.md` has the full real sequence and log
   output).
4. Verify the data is back (`recovery/recovery_verification.md`) — in this
   lab, all 5 deleted rows were restored, with the recovery log confirming
   it stopped one transaction short of the `DELETE`.

## Replication Workflow

1. Create a dedicated replication role (`replication/replication_setup.sql`)
   and grant it access via a specific `pg_hba.conf` entry
   (`replication/pg_hba.conf.sample`).
2. Initialize a standby with `pg_basebackup -R`
   (`replication/standby_setup.sh`), which copies the primary's data and
   automatically writes the `standby.signal` file and `primary_conninfo`
   needed to start streaming.
3. Start the standby and confirm it's streaming and caught up
   (`replication/replication_monitoring.sql`) — in this lab, `lag_bytes`
   was `0` and a row inserted on the primary appeared on the standby
   within ~2 seconds; the standby also correctly rejected a write attempt.

## Notes on Evidence

- All terminal output, log excerpts, timestamps, and row counts in
  `backups/`, `recovery/`, and `replication/` are real, captured from
  actually running these commands — not fabricated examples.
- Parts B-F were run against a disposable, isolated PostgreSQL sandbox
  cluster (separate data directories, separate ports) specifically so the
  destructive steps (disaster simulation, stopping the server, restoring
  over a data directory) never touched the shared `bootcamp` database used
  elsewhere.
- `wal_archiving/wal_setup.md` documents two real Windows-specific bugs
  encountered and fixed while getting `archive_command` to work (forward
  slashes vs. Windows `copy`, and PostgreSQL's config-file backslash
  escaping) — kept in as genuine troubleshooting evidence rather than
  smoothed over.
