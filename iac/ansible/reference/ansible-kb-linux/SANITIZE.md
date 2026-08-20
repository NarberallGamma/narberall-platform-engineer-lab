# Sanitize notes (this tree)

What was removed or rewritten before publish:

- Employer brand strings and internal apt / Sentry / Git hostnames
- Client legal names and trading-desk host prefixes
- Live inventory (`hosts.ini`, audit `inventory.ini`) replaced by `*.example`
- Live `pg_hba.conf` addresses remapped to `10.10.x.x`
- Postgres replication `id_rsa`, `authorized_keys`, and `known_hosts`
- Personal inventory user and author email
- Leftover-vendor playbook names (user / apt list generalized)
- Borg backup stub that only pointed at an internal Git host
- Package-update playbook tied to an employer brand (not copied)

What stayed (on purpose):

- Full PostgreSQL role: three major `postgresql.conf.j2`, sysctl, GRUB, `rc.local`, repmgr unit/cron
- Percona install graph and the comment-out of 5.7 knobs
- NTP role, `update_inventory`, and `tfadm` become flow
- `dapp-multiver` / `dapp-settings` (generic builder name) and `dapp_use`
- Ubuntu `audit.sh` section coverage (Russian headings are original)

Do not add real keys, live inventories, or vendor DSNs back into git.
