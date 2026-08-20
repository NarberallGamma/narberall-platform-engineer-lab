# Postgres replication SSH (local only)

Place the postgres user key material here before a run. These files stay on the control node and are not committed.

- `id_rsa` / `id_rsa.pub`: replication key used between cluster nodes
- `authorized_keys`: public keys allowed for the postgres user
- `known_hosts`: optional host pins

The role copies this directory to `{{ pg_home_dir }}/.ssh/` (mode 0600).
