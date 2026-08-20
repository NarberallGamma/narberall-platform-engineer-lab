# AWS host Ansible

**Business first:** AWS apply is not "done." Disks, databases, bastion, and backup become inventory the same week.

I used this tree after Terraform had already created AWS EC2 for databases, a backup host, and a bastion. Playbooks partition extra NVMe, install MySQL / MariaDB / MySQL 8 with optional replication, RethinkDB, Neo4j, ProxySQL plus an nginx stream frontend, land operator users, write `/etc/hosts` for MongoDB peers Neo4j talks to, and put `kubectl` plus a kubeconfig on the bastion.

This sits next to the published AWS Terraform: [`../../../terraform/aws/`](../../../terraform/aws/). Borg jobs that consume the backup host: [`../ansible-backup-borg/`](../ansible-backup-borg/). Hub: [`../`](../).

```text
ansible-aws-hosts/
  install_db.yml install_alt_dev_db.yml
  install_backup.yml install_bastion.yml
  create_user.yml update_hosts.yml
  roles/
    disks/             # parted, filesystem, UUID fstab mount
    db/                # mysql / mysql8 / mariadb / rethinkdb / neo4j / proxysql
    users/             # loop users + authorized_key from files/
    install-backup/    # jenkins + borg homes, Borg 1.1.6, postfix, HWE kernel
    install-bastion/   # kubectl pin, kubeconfig, bash completion
    hosts/             # /etc/hosts lines for Neo4j -> MongoDB
  inventories/hosts.ini.example
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `disks` | AWS NVMe: partition, ext4, UUID mount (`defaults,discard`) into `/var/lib/mysql` or `/backup` |
| `db` | One role, `db_type` switch, per-engine vars, `my.cnf.j2` with master/slave binlog, ProxySQL + nginx stream |
| `mysql_replication.yml` | `mysql_user` on master, `getslave` / `changemaster` / `startslave` using hostvars |
| `install-backup` | Borg storage host: users, binary, sudoers for jenkins cron deploy, postfix transport |
| `install-bastion` | kubectl from the Kubernetes apt repo, kubeconfig copied to root and to named users |
| `users` | Same file lookup for crypt password + SSH pubkey, different user lists per host group |

```bash
cp inventories/hosts.ini.example inventories/hosts.ini
for u in admin dba operator analyst developer platform; do
  cp "roles/users/files/${u}.password.example" "roles/users/files/${u}.password"
  cp "roles/users/files/${u}.pub.example" "roles/users/files/${u}.pub"
done
cp roles/install-backup/files/authorized_keys.borg.example roles/install-backup/files/authorized_keys.borg
cp roles/install-backup/files/authorized_keys.jenkins.example roles/install-backup/files/authorized_keys.jenkins
cp roles/install-bastion/files/config.example roles/install-bastion/files/config
cp roles/db/vars/replication_password.yml.example roles/db/vars/replication_password.yml
cp roles/db/vars/proxysql_passwords.yml.example roles/db/vars/proxysql_passwords.yml

ansible-playbook -i inventories/hosts.ini install_db.yml
ansible-playbook -i inventories/hosts.ini install_backup.yml
ansible-playbook -i inventories/hosts.ini install_bastion.yml
ansible-playbook -i inventories/hosts.ini create_user.yml
ansible-playbook -i inventories/hosts.ini update_hosts.yml
```

## Playbooks

| Playbook | Scope |
|----------|-------|
| `install_db.yml` | disks + db for mysql, mariadb, mysql8 (including report groups), rethinkdb, proxysql, neo4j |
| `install_alt_dev_db.yml` | disks + mysql on `alt-dev-mysql` |
| `install_backup.yml` | extra disk at `/backup`, then `install-backup` |
| `install_bastion.yml` | kubectl and kubeconfig for `admin`, `dba`, `platform` |
| `create_user.yml` | operator users per DB host group |
| `update_hosts.yml` | Neo4j `/etc/hosts` from `roles/hosts` |

## Roles

| Role | Job |
|------|-----|
| `disks` | `parted` + `filesystem` + UUID `mount` for `disks[provider]` |
| `db` | Engine install, `my.cnf` / RethinkDB instance / Neo4j / ProxySQL |
| `users` | `user` + `authorized_key` loop |
| `install-backup` | jenkins/borg users, Borg binary, monitoring sudoers, postfix |
| `install-bastion` | kubectl `1.15.4-00`, kubeconfig, completion |
| `hosts` | MongoDB peer lines for Neo4j (documentation IPs `203.0.113.x`) |

## Inventory contract

- Groups match playbook `hosts:` (`mysql`, `mysql8`, `mysql8-cs`, `mt5report_mysql8`, `mysql8-mt4report`, `mariadb`, `rethinkdb`, `neo4j`, `proxysql`, `backup`, `alt-dev-mysql`)
- `provider=aws` in inventory / `group_vars`
- Secrets: copy every `*.example` listed above. Never commit the live files.

## What is not in git

- Live SSH keys and crypt password files for operators
- Vaulted replication / ProxySQL passwords
- Live kubeconfig (certs / tokens)
- Real AWS public IPs (documentation ranges only)

## Keywords

Ansible, AWS, EC2, NVMe, MySQL, MariaDB, MySQL 8, replication, ProxySQL, Neo4j, RethinkDB, Borg, bastion, kubectl
