#!/usr/bin/env bash
# Part A: Restore the logical backup into a fresh test database.
set -euo pipefail

# 1. Create a test database
createdb bootcamp_check

# 2. Restore the backup into it
pg_restore -d bootcamp_check ~/backups/bootcamp.dump
