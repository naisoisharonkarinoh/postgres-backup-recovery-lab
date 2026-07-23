# Point-in-Time Recovery (PITR) Explanation

## What PITR Is

Point-in-Time Recovery is the ability to restore a PostgreSQL database to
its exact state at any specific moment in time — not just to the moment a
backup happened to be taken. It works by combining two things: a physical
base backup (a full copy of the data files at some starting point) and the
continuous archive of WAL segments generated since that backup (see
`wal_archiving/wal_setup.md`). Recovery replays those WAL records forward
from the base backup until it reaches the requested target — a timestamp
(`recovery_target_time`), a specific transaction (`recovery_target_xid`), a
named restore point, or a WAL position — and then stops, before that
target's changes (if any) are applied.

In this lab, `recovery/recovery_steps.md` shows this concretely: a base
backup was taken, a `DELETE FROM students` happened afterward, and PITR
replayed WAL up to (but not including) that `DELETE`'s transaction —
restoring all 5 rows without also restoring the accidental deletion.

## When Organizations Use PITR

- **Recovering from human error**: an accidental `DELETE`/`UPDATE`/`DROP`
  without a `WHERE` clause, a bad migration, or a mistaken bulk import —
  exactly the scenario simulated in `recovery/disaster_simulation.sql`.
- **Recovering from application bugs**: a deploy that silently corrupts
  data for some window of time before being caught.
- **Forensic/compliance investigation**: reconstructing what the database
  looked like at a specific past moment, e.g. "what did this customer's
  account balance show at 2:00 PM before the incident."
- **Recovering from certain kinds of malicious activity** (e.g. a
  compromised account issuing destructive statements), where the exact time
  of compromise can be identified and recovery targeted to just before it.

## Advantages Compared to Restoring Only From Backups

Restoring from a backup alone can only put the database back exactly as it
was *at backup time* — any legitimate work done between that backup and the
disaster is lost along with the bad change. PITR's advantages:

- **Fine-grained recovery point**: instead of losing everything since the
  last (say) nightly backup, PITR can recover to seconds before the actual
  disaster, minimizing data loss to just the bad transaction(s) themselves.
- **Fewer, cheaper full backups needed**: because WAL archiving fills the
  gap continuously, base backups can be taken relatively infrequently
  (e.g. weekly) without sacrificing recovery granularity — WAL replay
  covers everything in between.
- **Precise control over what's excluded**: PITR lets an operator choose a
  target that is deliberately just *before* a known-bad event, which a
  plain backup restore cannot do since a plain backup is a single fixed
  point with no finer resolution.
- **A single mechanism recovers from multiple disaster types**: the same
  base-backup-plus-WAL-archive setup handles both "restore to the most
  recent point" (RPO close to zero) and "restore to exactly the moment
  before a known bad event," without needing a separate strategy for each.

The cost is complexity: PITR requires WAL archiving to be continuously
configured and monitored (an archive gap breaks the replay chain), whereas
a plain backup/restore has no ongoing moving parts between backups.
