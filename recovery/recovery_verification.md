# Recovery Verification

## Record Count Before Deletion

Captured in `recovery/disaster_simulation.sql` immediately before the
`DELETE`:

```sql
SELECT count(*) FROM students;
```
```
 count
-------
     5
```

## The Disaster

```sql
DELETE FROM students;
```
```
DELETE 5
```
```sql
SELECT count(*) FROM students;
```
```
 count
-------
     0
```

## Record Count After Recovery

After completing the PITR steps in `recovery/recovery_steps.md` and
connecting to the recovered (and now promoted) server on port 5546:

```sql
SELECT count(*) FROM students;
```
```
 count
-------
     5
```

## Evidence That Data Was Successfully Restored

Row count alone confirms the total, but the actual row contents were
compared too, to rule out a coincidental count match:

```sql
SELECT id, name, email FROM students ORDER BY id;
```
```
 id |      name      |           email
----+----------------+----------------------------
  1 | Amina Wanjiru  | amina.wanjiru@example.com
  2 | Brian Otieno   | brian.otieno@example.com
  3 | Cynthia Njoki  | cynthia.njoki@example.com
  4 | David Kiptoo   | david.kiptoo@example.com
  5 | Esther Achieng | esther.achieng@example.com
```

This is byte-for-byte the same data that was seeded before the base backup
was taken, confirming the recovered database is not just the right *count*
but the correct *rows*. The PostgreSQL recovery log independently confirms
this was a genuine point-in-time recovery, not a coincidence: it explicitly
reports `recovery stopping before commit of transaction 766` — the
transaction ID of the `DELETE FROM students` statement — meaning WAL replay
stopped one transaction short of the disaster, exactly as
`recovery_target_time` requested.

**Conclusion: PITR successfully restored the database to its state
immediately before the accidental deletion, with zero data loss for any
transaction committed before the recorded disaster timestamp.**
