# Borg backup runner (werf teaching tree)

**Business first:** restore is a named job on a schedule, not a Friday hunt for who has the dump. Hub: [`../`](../).

I used this tree as the **Kubernetes runner**: a werf image with Borg, client CLIs, and supercronic, SSHing out to targets. There is no `Chart.yaml`. Host-side user, sudoers, and the same `borg_backup_*.sh` family also live in the Ansible kit: [`../../../../ansible/reference/ansible-backup-borg/`](../../../../ansible/reference/ansible-backup-borg/). This folder is the in-cluster packaging, not a second copy of that Ansible story.

```text
borg/
  werf.yml                  # same role as `werf.yaml` on the restic sibling; this tree kept the original name
  .helm/
    values.yaml
    secret-values.yaml.example
    vars/vars
    schedules/schedule-main
    templates/          # Secret, ConfigMaps, cron Deployment
  00-scripts/           # borg_backup_*.sh plus borg_run_on.sh
  ansible/              # borg-user.yaml + sudoers (copy authorized_keys.example)
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| werf-raw `.helm` | Runner image + Helm templates without `Chart.yaml` |
| supercronic Deployment | Recreate, checksum annotations, inotify reload of the crontab |
| `borg_run_on.sh` | Copy scripts, install Borg, fill `known_hosts`, run the job under `ssh-agent` |
| `00-scripts/borg_backup_*.sh` | Per-engine jobs (MySQL, Postgres, Mongo, files, WAL, etcd, Vault, kube PVC) |

```bash
cp ansible/authorized_keys.example ansible/authorized_keys
cp .helm/secret-values.yaml.example .helm/secret-values.yaml
# edit .helm/vars/vars (repo SSH target + PROJECT)

cd ansible
ansible-playbook -bK -i mysql-prod-0.estate.example.com, borg-user.yaml

# from the runner (or after werf converge):
./00-scripts/borg_run_on.sh mysql-prod-0.estate.example.com borg_backup_mysql.sh 'MYSQL'
```

`borg_run_on.sh` takes `host[:port[:proxy[:proxy_port]]]`. Touch `UNDER_KUBERNETES` so the job does not wrap `logger`.

Alerting CLI on the image is optional `backup_notify`. Vendor installer binaries stay out.

## Inventory contract

- Borg repo SSH target: `BORG_SERVER` in `.helm/vars/vars` (see `vars.example`)
- Keys: `ansible/authorized_keys.example` (copy to `authorized_keys`, never commit the live file)
- Helm secrets: `.helm/secret-values.yaml.example` (`CHANGE_ME`)

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

**Keywords:** Borg, werf, supercronic, backup, SSH, prune
