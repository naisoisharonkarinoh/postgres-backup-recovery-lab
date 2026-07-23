#!/usr/bin/env bash
# Part B: Prepare the WAL archive directory, apply the archiving config,
# and take a base backup.
set -euo pipefail

# 1. Create the WAL archive destination directory
mkdir -p ~/backups/wal

# 2. Apply wal_level/archive_mode/archive_command from postgresql.conf.sample,
#    then restart PostgreSQL so the (postmaster-context) settings take effect
sudo systemctl restart postgresql

# 3. Take a base backup: tar format, gzip-compressed, WAL streamed alongside,
#    with progress reporting
pg_basebackup -D ~/backups/base -Ft -z -Xs -P
