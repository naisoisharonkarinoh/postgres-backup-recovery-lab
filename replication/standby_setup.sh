#!/usr/bin/env bash
# Part E: Initialize a standby from the primary using pg_basebackup -R.
set -euo pipefail

pg_basebackup -h 127.0.0.1 -U replicator -D ~/standby -R -P

# What -R does:
#
# -R (--write-recovery-conf) tells pg_basebackup to automatically write the
# replication configuration needed to turn the copied data directory into a
# working standby, instead of the operator having to hand-write it:
#
#   1. It creates a "standby.signal" file in the target data directory,
#      which is what tells PostgreSQL on startup to enter standby mode
#      (continuously replay WAL from a primary) rather than starting up as
#      a normal read-write server.
#   2. It writes a "primary_conninfo" setting into postgresql.auto.conf,
#      containing the connection string (host, port, user, password, SSL
#      preferences, etc.) the standby will use to connect to the primary
#      and start streaming replication as soon as it starts up.
#
# Without -R, both of these would have to be created and populated by hand
# after the base backup finished.
