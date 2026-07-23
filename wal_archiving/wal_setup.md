# WAL Archiving Setup

## What WAL Is

The Write-Ahead Log (WAL) is PostgreSQL's durability mechanism: before any
change to a data page is applied, PostgreSQL first writes a record of that
change to a sequential, append-only log (the WAL). Only after the WAL record
is safely flushed to disk does PostgreSQL consider the change durable — the
actual data-file pages can be written out later (e.g. at the next
checkpoint). If the server crashes, PostgreSQL replays the WAL since the
last checkpoint on startup to bring the data files back to a consistent
state. WAL is physically stored as a sequence of fixed-size (16MB by
default) segment files in the `pg_wal/` directory of the data directory.

## Why WAL Archiving Is Needed

By default, PostgreSQL recycles WAL segments once they're no longer needed
for crash recovery — it doesn't keep them forever. That's fine for crash
recovery, but it means the *only* copies of your data's incremental history
are transient. **Archiving** means copying each completed WAL segment
somewhere durable (`archive_command`) before PostgreSQL is allowed to
recycle it. Once archived, that WAL segment becomes part of a permanent,
replayable history of every change made to the database — which is exactly
what backup and recovery beyond "restore the last full backup" requires.

## How PITR Depends on WAL Archives

A base backup (via `pg_basebackup`) only captures the data files as they
existed at one point in time. Point-in-Time Recovery (PITR) works by
restoring that base backup and then **replaying archived WAL segments**
forward from the backup's start point up to any target moment you choose
(a timestamp, a transaction ID, or a named restore point). Without the
archived WAL segments covering that window, recovery could only ever land
exactly on the moment the base backup was taken — no finer-grained recovery
would be possible. The archive is what turns a single static backup into a
continuous, replayable timeline.

## What `pg_basebackup` Accomplishes

`pg_basebackup` takes a full, consistent copy of a running PostgreSQL data
directory over the replication protocol, without requiring the server to be
stopped. It's the "full backup" anchor point that WAL replay is layered on
top of for PITR, and (used with `-R`) it is also how standby servers are
initialized for streaming replication (see `replication/standby_setup.sh`).
Flags used in this lab: `-Ft` (tar format), `-z` (gzip-compress the tars),
`-Xs` (stream the WAL generated during the backup alongside it, so the
backup is self-contained/immediately restorable), `-P` (show progress).

## Real Evidence From This Lab

WAL archiving and `pg_basebackup` were both run for real against an
isolated PostgreSQL 18.4 sandbox cluster (not the shared `bootcamp` server —
see the note on the Windows adaptation below).

**Verifying archiving actually works** (`pg_switch_wal()` forces a segment
to close early so it becomes eligible for archiving immediately):

```
lab=# SELECT pg_switch_wal();
 pg_switch_wal
---------------
 0/3005898

lab=# SELECT archived_count, last_archived_wal, last_archived_time, failed_count
      FROM pg_stat_archiver;
 archived_count |    last_archived_wal     |      last_archived_time       | failed_count
----------------+--------------------------+-------------------------------+--------------
              3 | 000000010000000000000003 | 2026-07-23 16:41:58.826188+03 |            3
```

```
$ ls -la wal_archive/
-rw-r--r-- 1 naiso 197610 16777216 Jul 23 16:41 000000010000000000000002
-rw-r--r-- 1 naiso 197610 16777216 Jul 23 16:41 000000010000000000000003
```

(`failed_count` reflects earlier attempts made while the Windows-specific
`archive_command` was still being debugged — see below — not ongoing
failures; `archived_count` and the files on disk confirm archiving was
working correctly by the time the base backup and later PITR were run.)

**`pg_basebackup` output:**

```
$ pg_basebackup -h 127.0.0.1 -p 5544 -U postgres -D ~/backups/base -Ft -z -Xs -P -c fast
waiting for checkpoint
  237/49208 kB (0%), 0/1 tablespace
49219/49219 kB (100%), 0/1 tablespace
49219/49219 kB (100%), 1/1 tablespace

$ ls -la ~/backups/base
backup_manifest    182,587 bytes
base.tar.gz       7,167,094 bytes
pg_wal.tar.gz        17,123 bytes
```

## Note on the Windows Adaptation

The lab's prescribed `archive_command = 'cp %p /home/$USER/backups/wal/%f'`
is written for Linux. This lab was executed on Windows, where `cp` is not a
built-in shell command. Two issues had to be worked around to get **real**
archiving evidence (documented here rather than silently glossed over):

1. Windows' `copy` built-in cannot parse the forward-slash paths PostgreSQL
   substitutes for `%p`/`%f` ("The syntax of the command is incorrect").
2. PostgreSQL's own config-file parser treats backslashes in
   `archive_command` as escape sequences, so a Windows-style path like
   `C:\Program Files\Git\usr\bin\cp.exe` gets silently mangled
   (`\P`, `\G`, `\u`, `\b`, `\i` are stripped) before the command even
   reaches the shell.

The working fix was to point `archive_command` at Git for Windows' real
`cp.exe`, written entirely with forward slashes so PostgreSQL's config
parser doesn't treat any character as an escape:

```
archive_command = '"C:/Program Files/Git/usr/bin/cp.exe" %p "C:/Users/naiso/AppData/Local/Temp/pg-sandbox/wal_archive/%f"'
```

`sudo systemctl restart postgresql` also does not apply on Windows (no
systemd); the equivalent step used here was `pg_ctl reload` (for the
`archive_command`/`archive_mode` change, since `archive_mode` needs a full
restart the first time it's enabled, `pg_ctl restart` was used instead).
