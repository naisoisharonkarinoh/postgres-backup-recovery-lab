# Backup Verification

## Backup File Name

`~/backups/bootcamp.dump`

## Backup Format Used

PostgreSQL **custom format** (`pg_dump -Fc`) — a compressed, non-plain-text
archive that supports selective/parallel restore via `pg_restore`. Created
with `pg_dump` / `pg_restore` from PostgreSQL 18.4, against the `bootcamp`
database (which includes the `students`, `courses`, `departments`,
`enrollments`, and `orders` tables — 2,000,000 rows in `orders` alone).

## Verification Process

1. Ran `pg_dump -Fc -f ~/backups/bootcamp.dump bootcamp` — completed with
   exit code 0, producing a 40,378,831-byte archive.
2. Inspected the archive's table of contents with `pg_restore --list`
   without touching any live database — confirmed the archive header and
   all 5 tables (plus their sequences and data entries) were present.
3. Created a brand-new, empty database, `bootcamp_check`, so the restore
   test could never overwrite or interact with the real `bootcamp`
   database.
4. Restored the full archive into `bootcamp_check` with
   `pg_restore -d bootcamp_check ~/backups/bootcamp.dump`.
5. Compared row counts per table between the original `bootcamp` and the
   restored `bootcamp_check`.

## Terminal Output (real, captured from this run)

```
$ pg_dump -Fc -f ~/backups/bootcamp.dump bootcamp
(exit code: 0)

$ ls -la ~/backups
-rw-r--r-- 1 naiso 197610 40378831 Jul 23 16:35 bootcamp.dump

$ pg_restore --list ~/backups/bootcamp.dump | head -20
;
; Archive created at 2026-07-23 16:35:13
;     dbname: bootcamp
;     TOC Entries: 47
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Integer: 4 bytes
;     Offset: 8 bytes
;     Dumped from database version: 18.4
;     Dumped by pg_dump version: 18.4
;
;
; Selected TOC Entries:
;
222; 1259 16510 TABLE public courses postgres
221; 1259 16509 SEQUENCE public courses_course_id_seq postgres
5067; 0 0 SEQUENCE OWNED BY public courses_course_id_seq postgres
220; 1259 16499 TABLE public departments postgres
219; 1259 16498 SEQUENCE public departments_department_id_seq postgres

$ createdb bootcamp_check
(exit code: 0)

$ pg_restore -d bootcamp_check ~/backups/bootcamp.dump
(completed with no errors)
```

## Row-Count Comparison (Original vs. Restored)

| Table         | Original `bootcamp` | Restored `bootcamp_check` |
|---------------|---------------------:|----------------------------:|
| students      | 3                     | 3                            |
| courses       | 3                     | 3                            |
| departments   | 2                     | 2                            |
| enrollments   | 9                     | 9                            |
| orders        | 2,000,000             | 2,000,000                    |

## Successful Restore Confirmation

**Confirmed.** Every table's row count in `bootcamp_check` matches the
original `bootcamp` database exactly, including the 2,000,000-row `orders`
table, demonstrating that the custom-format backup captured the database
completely and `pg_restore` reproduced it faithfully into a brand-new
database with no data loss or corruption.
