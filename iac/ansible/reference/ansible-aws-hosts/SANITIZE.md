# Sanitize notes (this tree)

What was removed or rewritten before publish:

- Personal Linux account names (mapped to `admin`, `dba`, `operator`, `analyst`, `developer`, `platform`)
- Live SSH public keys and crypt password files (`*.example` with `CHANGE_ME` / lab keys)
- Vaulted `replication_password.yml`, `proxysql_passwords.yml`, and kubeconfig (`config.example`)
- Live AWS public IPs in ProxySQL, nginx stream, and Neo4j `/etc/hosts` (now `10.10.x.x` / `203.0.113.x`)
- Client domain on Neo4j advertised address (`estate.example.com`)
- Live Neo4j `SECRETS.PASSWORD`
- Vendor SMTP transport host (`mail.example.com`)
- Application usernames in ProxySQL that identified the estate (`app_external`, `app_dev`)

What stayed (on purpose):

- Full `db` task graph: mysql, mysql8, mariadb, replication, rethinkdb, neo4j plugins wget, proxysql + nginx stream
- `disks` UUID mount loop and `install-backup` postfix / HWE / Borg pin
- Host group names that describe workloads (`mt5report_mysql8`, `mysql8-mt4report`)
- Original task names, including typos (`autocomplection`, `mounetd`)

Do not add live PEM, kubeconfig, or operator keys back into git.
