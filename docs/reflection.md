# Reflection

Backups stopped being an abstract checklist item for me the moment
`pg_restore --list` returned a real table of contents and the row counts in
`bootcamp_check` matched `bootcamp` exactly, down to all 2,000,000 rows in
`orders`. What stuck with me is how much of "having a backup" is actually
"having *verified* a backup" — a `.dump` file sitting on disk that's never
been restored is a guess, not a guarantee. The verification step (restore
into a throwaway database, compare row counts) is cheap and is the entire
difference between the two.

PITR's value became obvious in a way documentation never quite conveys once
I watched the recovery log itself say "recovery stopping before commit of
transaction 766" — the exact transaction of my `DELETE FROM students` — and
then queried the table and found all 5 rows back. A plain backup restore
could only have gotten me back to whenever the last base backup ran, losing
everything since. PITR got me back to one transaction before the disaster,
which is a fundamentally different, much stronger guarantee.

The replication setup was where I actually hit real failures, and they
were more instructive than if everything had worked first try. Windows'
`copy` command silently rejects the forward-slash paths PostgreSQL passes
to `archive_command`, and PostgreSQL's own config parser treats backslashes
as escape characters and quietly mangles a Windows path before it even
reaches the shell — both failed *without* an obviously-related error
message at first. The more interesting bug came later: my first standby
attempt inherited `recovery_target_time` and `recovery_target_action` from
the primary's `postgresql.conf` (since `pg_basebackup` copies that file
wholesale), so the standby immediately treated itself as a targeted
recovery and self-promoted instead of streaming. That one taught me
something not obvious from reading about replication in the abstract: a
standby isn't just "a copy that follows the primary," it's a full recovery
process with its own config, and config meant for one recovery scenario can
silently leak into and corrupt a different one.

That experience is also why testing recovery procedures matters as much as
having them: every failure here happened on the *first* real attempt,
despite the configuration looking correct on paper. If this had been a
real incident instead of a lab, discovering these bugs during the incident
— rather than beforehand, with no time pressure — would have been much
worse.

If I had to pick the most realistic part of the lab, it's the replication
debugging, precisely because it wasn't clean. Real operations work is
mostly discovering the gap between "the documented steps" and "what
actually happens on this specific system."
