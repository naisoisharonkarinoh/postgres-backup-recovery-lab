# Replication Analysis

## Why Replication Is Important

Replication keeps one or more additional, continuously up-to-date copies of
the database running on separate servers. Its value is availability and
scale, not archival history: if the primary server fails — hardware
failure, OS crash, a bad deploy that takes the process down — a standby
that was already streaming WAL can be promoted to take over with
(depending on lag) little to no data loss and far less downtime than
restoring from any kind of backup. In this lab, `replication/standby_setup.sh`
and `replication/replication_monitoring.sql` demonstrate a real standby
staying continuously synchronized with the primary via streaming
replication.

## Difference Between Backups and Replication

These solve different problems and are not substitutes for each other:

| | Backups (logical or physical+WAL) | Replication |
|---|---|---|
| Protects against | Data loss, corruption, "I need yesterday's/last week's data back" | Server/hardware failure, downtime |
| Recovery point | Any point covered by the backup + archived WAL (PITR) | Effectively "now" (whatever the standby has replayed) |
| Recovery speed | Slower — restore + replay | Fast — promote a standby that's already running |
| Protects against bad writes | **Yes** — can recover to before the bad write | **No** — a `DELETE` on the primary replicates to the standby too |
| Where it lives | Ideally off-site/offline, decoupled from the primary | Typically online, network-reachable, actively running |

The critical point: replication is **not** a backup. A mistaken
`DELETE FROM students` (as simulated in `recovery/disaster_simulation.sql`)
would have replicated to the standby in this lab within seconds — a standby
protects against server failure, not against bad statements executed on
good hardware. Both are needed for a complete strategy.

## Benefits of Streaming Replication

- **Continuous, low-lag synchronization**: the standby applies WAL almost
  as fast as the primary generates it. `replication/replication_monitoring.sql`
  recorded `lag_bytes = 0` in this lab's real test — the standby was fully
  caught up.
- **Fast failover**: because the standby already has the data and is
  already running, promoting it (`pg_promote()` or `pg_ctl promote`) is far
  faster than restoring a backup from scratch.
- **Read scaling**: a streaming standby can serve read-only queries
  (confirmed in this lab — the standby correctly answered `SELECT`s), which
  can offload reporting/analytics traffic from the primary. This lab also
  confirmed the standby genuinely rejects writes
  (`ERROR: cannot execute INSERT in a read-only transaction`), which is the
  expected safety guarantee of a standby.
- **Low setup overhead**: `pg_basebackup -R` (see `replication/standby_setup.sh`)
  automatically wires up both the initial data copy and the ongoing
  connection info in one command.

## Scenarios Where Replication Improves Availability

- **Primary server hardware failure**: promote the standby; clients are
  redirected to it with minimal downtime.
- **Planned maintenance/upgrades**: failover to a standby, patch/upgrade
  the now-idle former primary, then either fail back or promote a fresh
  standby from it.
- **Read-heavy workloads**: routing reporting/analytics queries to a
  standby keeps that load off the primary, improving the primary's
  availability for write traffic.
- **Geographic distribution**: a standby in a different region/data center
  protects against a region-level outage, and can also serve reads with
  lower latency to geographically distant users.
