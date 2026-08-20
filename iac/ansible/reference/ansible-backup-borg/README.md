# Borg backup kit

**Business first:** restore is a named job before the incident, not a Friday hunt for who has the dump.

I used this tree to land a dedicated `borg` user with sudoers on backup targets, then run per-engine Borg jobs from a runner host over SSH. The playbooks are small on purpose. The living weight is the `00-scripts/borg_backup_*.sh` family: MySQL (innobackupex / xtrabackup / mysqldump), PostgreSQL (physical and `pg_dump`), MongoDB, Redis, ClickHouse, files, WALs, GitLab, etcd, Prometheus, Sentry, Neo4j, and kube-side dumps.

The same borg-user / sudoers-borg role was reused on several estates. I am not publishing four copies.

Hub: [`../`](../). AWS hosts that mount `/backup` and install Borg on the storage host: [`../ansible-aws-hosts/`](../ansible-aws-hosts/).

```text
ansible-backup-borg/
  ansible/
    borg-user.yaml              # user, authorized_keys, sudoers
    borg-mysql-user.yaml        # ~borg/.my.cnf for dump jobs
    mysql-config.j2
    mysql-inventory.example
    mysql-passwords.yml.example
    authorized_keys.example
    sudoers-borg
  00-scripts/                   # borg_backup_*.sh plus runners
  vars.example
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `borg-user.yaml` | Idempotent backup principal: home, `0400` key, visudo-validated sudoers |
| `borg-mysql-user.yaml` | Client defaults for dump/xtrabackup jobs (password stays in `*.example`) |
| `borg_run_on.sh` | Copy scripts to the target, install Borg, fill `known_hosts`, run the job under `ssh-agent` |
| `borg_backup_mysql.sh` and siblings | Real option parsing, prune policy, stdin/stream into `borg create` |
| `alert()` | Failure path calls `backup_notify` (estate alerting CLI). Jobs still print ERROR if that binary is missing |

```bash
cp vars.example vars
cp ansible/authorized_keys.example ansible/authorized_keys
cp ansible/mysql-inventory.example ansible/mysql-inventory
cp ansible/mysql-passwords.yml.example ansible/mysql-passwords.yml

cd ansible
ansible-playbook -bK -i mysql-prod-0.estate.example.com, borg-user.yaml
ansible-playbook -bK -i mysql-inventory borg-mysql-user.yaml

# from the kit root, after vars is in place:
./00-scripts/borg_run_on.sh mysql-prod-0.estate.example.com borg_backup_mysql.sh 'MYSQL'
```

`borg_run_on.sh` takes `host[:port[:proxy[:proxy_port]]]`. Kubernetes runner: `borg_run_on_kube.sh` (touch `UNDER_KUBERNETES` so the job does not wrap `logger`).

## Playbooks

| Playbook | Scope |
|----------|-------|
| `ansible/borg-user.yaml` | `borg` user, SSH dir, authorized_keys, `/etc/sudoers.d/borg` |
| `ansible/borg-mysql-user.yaml` | `~borg/.my.cnf` from `mysql-config.j2` |

## Scripts

| Script | Job |
|--------|-----|
| `borg_install.sh` | Pin Borg `1.1.17` binary into `/usr/local/bin` |
| `borg_run_on.sh` / `borg_run_on_kube.sh` | Remote copy + execute |
| `wrapper_ssh-agent.sh` | Cron wrapper that loads `~/.ssh/.borg-${PROJECT}` |
| `borg_backup_mysql.sh` | innobackupex stream |
| `borg_backup_xtrabackup.sh` | xtrabackup stream |
| `borg_backup_mysqldump.sh` | logical MySQL dump |
| `borg_backup_postgres.sh` / `_stdout` / `pg_dump` | physical and logical PostgreSQL |
| `borg_backup_mongo.sh` | mongodump |
| `borg_backup_redis.sh` | Redis dump |
| `borg_backup_clickhouse.sh` | FREEZE PARTITION then files |
| `borg_backup_files.sh` | generic `borg create` + prune |
| `borg_backup_wals.sh` | PostgreSQL WAL archive |
| plus etcd, GitLab, Elasticsearch dump, Prometheus, Sentry, Neo4j, kube mysqldump / PMM |

## Inventory contract

- Borg repo SSH target: `BORG_SERVER` in `vars` (copy `vars.example`)
- MySQL hosts: `ansible/mysql-inventory.example`
- Keys: `ansible/authorized_keys.example` (never commit the live file)
- MySQL password: `mysql-passwords.yml.example` (`CHANGE_ME`)

## What is not in git

- Live `authorized_keys`, vaulted `mysql-passwords.yml`, live `vars`
- Helm / Werf / GitLab CI packaging that wrapped the runner image
- Vendor alerting installer binary

## Keywords

Ansible, Borg, MySQL, PostgreSQL, MongoDB, Redis, ClickHouse, xtrabackup, WAL, sudoers, backup user, prune
