# Borg backup (werf-raw)

**Business first:** the backup runner is a **Cron in the cluster**, not a laptop crontab. Hub: [`../`](../). Host playbooks and the same script family: [`../../../../ansible/reference/ansible-backup-borg/`](../../../../ansible/reference/ansible-backup-borg/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

This is the richest Borg tree that has **no Chart.yaml**. Werf builds an Ubuntu image with Borg 1.1.17, supercronic, and MySQL/Postgres/Mongo clients. Helm templates (werf-raw) mount an SSH key and per-engine secret files, then start `entrypoint.sh <env>` which copies `vars-<env>` / `schedule-<env>` and execs supercronic.

```text
backup-werf/
  werf.yaml                 # image: borg + clients; no Chart.yaml
  entrypoint.sh
  schedule / schedule-staging / schedule-production
  vars.example
  .gitlab-ci.yml              # werf lint / render / converge
  .gitignore                  # secret-values.yaml, vars-*, rendered output
  .helm/
    values.yaml             # resource pluck by werf.env
    secret-values.example.yaml
    templates/
      05-secret-ssh-key.yaml
      10-secrets.yaml       # mysql cnf + mongo passwords
      20-cron.yaml          # Deployment + checksum annotations
      _resources.tpl
  00-scripts/               # borg_backup_*.sh plus wrapper_ssh-agent.sh, borg_run_on.sh, borg_run_on_kube.sh
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| No Chart.yaml | Werf-raw: templates + values only |
| Cron Deployment | Recreate, mounts `ssh-key` and `backup-secrets`, runs supercronic |
| Schedule density | etcd, MySQL xtrabackup + binlog, several Mongo jobs, Neo4j |
| `10-secrets.yaml` | `pluck` by `werf.env` for mysql cnf and mongo password files |
| Scripts | Real option parsers and prune. Host install stays in the Ansible kit |

```bash
cp vars.example vars-staging
cp vars.example vars-production
cp .helm/secret-values.example.yaml .helm/secret-values.yaml
# fill CHANGE_ME, then:
# werf converge --env staging
```

## Secrets

`ssh_key`, mysql client cnf, and mongo passwords live in `.helm/secret-values.yaml` (gitignored). Example file uses `CHANGE_ME` only. No PEM block is committed.

## What is not in git

- Live Borg server address and project name (use `vars.example`)
- Live `authorized_keys` / vaulted mysql passwords (Ansible kit examples)
- Vendor alerting installer binary that the original image fetched at build

**Keywords:** Borg, werf, supercronic, MySQL, MongoDB, Neo4j, etcd, xtrabackup
