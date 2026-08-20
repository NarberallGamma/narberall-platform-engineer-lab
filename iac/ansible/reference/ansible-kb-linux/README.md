# Linux KB Ansible (PostgreSQL, Percona, NTP, host audit)

**Business first:** databases stay timed, replicated, and auditable. A missing NTP or an unowned Postgres is an incident, not a later ticket.

I ran this class of playbooks on Linux estates next to Deckhouse-era Kubernetes work. The jobs are ordinary and unforgiving: PostgreSQL with repmgr, Percona Server on Ubuntu, NTP pinned from a generated inventory, and a sudo host audit I can pull back to the control node. This tree is the living roles. I did not thin them into a three-task demo.

Hunter map: [`../../`](../../). Six years: [`../../../../docs/experience.md`](../../../../docs/experience.md). Sibling kits: [`../`](../).

Brand, live IPs, personal keys, and client host lists are stripped. Role graphs, Jinja (`postgresql.conf` for 9.6 / 10 / 11), sysctl / GRUB / hugepage files, and the audit script stay almost intact so a reviewer can parse real Linux ops, not a stub.

```text
ansible-kb-linux/
  playbooks/              # dapp-multiver, percona, software-versions, remove-legacy-vendor
  roles/
    dapp-multiver/        # multi-version dapp gem on gitlab-runner (RVM, docker-ce)
    dapp-settings/        # per-runner settings.toml (Sentry DSN is CHANGE_ME)
    percona/              # Percona Server 5.7 plus an internal apt overlay
  postgresql/             # own ansible.cfg, inventory, mitogen note, full role
    projects/postgresql/roles/postgresql/
  setup_ntpd/             # ntpd role + update_inventory from ~/.ssh/config
  extras/ubuntu-audit/    # audit.sh + run_audit.yml
  scripts/make_inventory_from_ssh_config.sh
```

`dapp` here is the historical Ruby build tool (the line that later became werf), not a client product. Role names stay `dapp-multiver` and `dapp-settings`.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `roles/postgresql` | Official PGDG packages, templated `postgresql.conf` per major, `pg_hba`, sysctl, GRUB hugepages, `rc.local` THP off, repmgr + repmgrd + cron cleanup |
| `roles/percona` | Vendor repo, config package, comment-out of unsafe 5.7 knobs, then the server |
| `setup_ntpd` | Estate-wide NTP from SSH-config inventory (`tfadm` become password on localhost first) |
| `extras/ubuntu-audit` | One script, many hosts: disks, ports, firewall, apt, docker, kubectl, mysql/postgres, failed units |
| `dapp-multiver` | Build-node bootstrap: gitlab-runner, docker-ce, RVM Ruby 2.5.3, several dapp gemsets |

```bash
# PostgreSQL + repmgr (from postgresql/)
cp postgresql/inventory/hosts.ini.example postgresql/inventory/hosts.ini
# place postgres replication key under
# postgresql/projects/postgresql/roles/postgresql/files/.ssh/
cd postgresql && ansible-playbook projects/postgresql/postgresql.yml

# Percona
ansible-playbook -i estate-db-0.example.com, playbooks/percona.yml

# NTP
cp setup_ntpd/inventories/hosts.ini.example setup_ntpd/inventories/hosts.ini
cd setup_ntpd && ansible-playbook setup_ntpd.yml
# or rebuild YAML inventory from ~/.ssh/config:
# ./update_inventory --project-filter "estate" && ansible-playbook setup_ntpd.yml

# Host audit
cp extras/ubuntu-audit/inventory.ini.example extras/ubuntu-audit/inventory.ini
ansible-playbook -i extras/ubuntu-audit/inventory.ini extras/ubuntu-audit/run_audit.yml
```

## Playbooks

| Playbook | Scope |
|----------|-------|
| `postgresql/projects/postgresql/postgresql.yml` | PostgreSQL + repmgr on group `postgresql` |
| `playbooks/percona.yml` | Percona Server 5.7 on `all` |
| `setup_ntpd/setup_ntpd.yml` | ntpd on `all`, optional `tfadm` sudo prompt |
| `playbooks/dapp-multiver.yml` | gitlab-runner build node: dapp-multiver + dapp-settings |
| `playbooks/software-versions.yml` | `package_facts` dump per host |
| `playbooks/remove-legacy-vendor.yml` | Drop leftover vendor user, apt list, and essm |
| `extras/ubuntu-audit/run_audit.yml` | Remote `audit.sh`, logs on the control node |

## Roles

| Role | Job |
|------|-----|
| `postgresql` | Packages, config templates (9.6/10/11), HBA, replication SSH, repmgrd, host sysctl/GRUB |
| `percona` | Percona repo + server; internal `apt.example.com` overlay for shared config |
| `setup_ntpd` | Install ntp, render `ntp.conf` (pool + restrict default ignore) |
| `dapp-multiver` | Runner, docker-ce, RVM, dapp gem, `dapp_use` on PATH |
| `dapp-settings` | `~gitlab-runner/.dapp/settings.toml` |

## Inventory contract

- PostgreSQL: `postgresql/inventory/hosts.ini.example` (`10.10.10.11` / `10.10.10.12`)
- NTP: `setup_ntpd/inventories/hosts.ini.example` or YAML from `update_inventory` (generated `inventories/*.yml` is gitignored)
- Audit: `extras/ubuntu-audit/inventory.ini.example` (`admin`, `estate.*` names)
- Secrets: Sentry DSN in `dapp-settings` is `CHANGE_ME`; vault password file path in `postgresql/ansible.cfg` stays `~/.ansible_vault_pass.txt` on the control node
- Postgres replication keys: local path `postgresql/projects/postgresql/roles/postgresql/files/.ssh/` (see README there)

## Keywords

Ansible, PostgreSQL, repmgr, Percona, NTP, Ubuntu audit, dapp, werf-era, Deckhouse-era, gitlab-runner, RVM, sysctl, hugepages
