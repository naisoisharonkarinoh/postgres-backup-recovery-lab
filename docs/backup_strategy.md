# Backup Strategy

## Logical Backups

A logical backup (`pg_dump`) exports the database as a sequence of SQL
statements or a portable archive (this lab used the custom format, `-Fc`)
describing how to *recreate* the data — as opposed to a physical backup,
which copies the raw data files byte-for-byte. Logical backups are:

- **Portable**: `bootcamp.dump` (produced in `backups/backup_commands.sh`)
  can be restored into any compatible PostgreSQL version/platform, and even
  selectively (`pg_restore` can restore just one table or schema).
- **Consistent by construction**: `pg_dump` runs inside a single
  transaction using a consistent MVCC snapshot, so the backup reflects the
  database at one exact instant even while other transactions are writing.
- **Slower to restore at scale** than a physical restore, since restoring
  means re-running DDL and re-inserting/re-indexing data rather than just
  copying files back.

This makes logical backups the right tool for: full-database exports before
a risky migration, moving data between environments, and cases where a
human needs to inspect or selectively restore parts of a backup.

## Backup Verification

A backup that has never been restored is not a verified backup — corruption,
truncation, or a bad flag can silently produce a file that looks fine but
won't restore. This lab's verification process (`backups/backup_verification.md`)
follows the pattern any real strategy should use:

1. Take the backup.
2. Inspect its table of contents (`pg_restore --list`) without touching any
   live database, to catch obviously broken archives early.
3. Restore it into a **new, disposable** database — never the original —
   so verification can never damage real data.
4. Compare row counts (and ideally checksums/spot-checked data) between the
   original and the restored copy.

Only after this process passed — row counts matched exactly, including the
2,000,000-row `orders` table — was the backup in this lab considered
verified.

## Backup Frequency Recommendations

Frequency should be driven by how much data loss is tolerable (Recovery
Point Objective, RPO), not by convenience:

- **Logical backups (`pg_dump`)**: daily is a reasonable baseline for most
  applications, since they're relatively expensive (they scan the whole
  database) and are usually a secondary/portable safety net rather than the
  primary recovery mechanism.
- **Physical base backups**: weekly is common as the PITR anchor point,
  since WAL archiving (see `docs/pitr_explanation.md`) covers the gap
  between base backups at much lower overhead than repeating a full backup
  more often.
- **WAL archiving**: continuous — this is what actually determines RPO in a
  PITR setup. With WAL archived continuously, RPO can be seconds, regardless
  of how infrequent the base backups are.

## Off-Site Backup Recommendations

A backup that lives on the same disk/server as the database it protects
does not protect against the most common real disasters: disk failure,
accidental deletion of the whole server, ransomware, or a data-center-level
outage. At minimum:

- Copy backups (both logical dumps and physical base backups/WAL archives)
  to a separate physical location or cloud object storage (e.g. S3-
  compatible storage) on a schedule at least as frequent as the backups
  themselves are taken.
- Encrypt backups in transit and at rest, since an off-site copy is also an
  additional location an attacker could target.
- Periodically test restoring from the off-site copy specifically, not just
  the local copy — off-site transfer is itself a failure point (partial
  uploads, expired credentials, silently broken cron jobs).
- Apply a retention policy (e.g. keep daily backups for 2 weeks, weekly for
  2 months, monthly for a year) so off-site storage cost doesn't grow
  unbounded while still preserving enough history to recover from problems
  that go unnoticed for a while.
