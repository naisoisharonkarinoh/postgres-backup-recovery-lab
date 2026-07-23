#!/usr/bin/env bash
# Part A: Create a logical (custom-format) backup of the bootcamp database.
set -euo pipefail

# 1. Create a backup directory
mkdir -p ~/backups

# 2. Perform a PostgreSQL custom-format backup
pg_dump -Fc -f ~/backups/bootcamp.dump bootcamp

# 3. List the contents of the backup
pg_restore --list ~/backups/bootcamp.dump | head
