# Sanitize notes (this tree)

What was removed or rewritten before publish:

- Employer and vendor brand strings
- Personal admin and database usernames
- Live inventory IPs and public EIPs
- Live PostgreSQL password in `db-create.yaml`
- EDR vendor `.deb` packages (role still installs `files/edr-agent.deb`)
- Real people SSH keys (replaced by `admin.pub.example` / `admin01.pub.example`)
- Live Kafka PEM and CA files (replaced by `*.pem.example` / `ca.crt.example`)
- Vault env names that named a private estate

What stayed (on purpose):

- Full playbooks, including the `hardering.yml` filename
- Role graphs for Kafka mTLS, EDR, cron harden, Prometheus, node_exporter, Postgres lifecycle
- Inventory groups and host roles (IPs rewritten to documentation ranges)
- Helper scripts: `db.convert.py`, `kafka-mtls-cert.sh`, `s3-create.sh`, `db.yml.sh`
- Russian operator comments inside roles (original operator language)

Do not add real certificates, EDR packages, SSH keys, or live `inventory.ini` back into git.
