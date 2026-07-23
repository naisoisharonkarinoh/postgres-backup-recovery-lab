-- Part E: Create a replication account on the primary.

CREATE ROLE replicator WITH REPLICATION
LOGIN
PASSWORD 'rppass';
