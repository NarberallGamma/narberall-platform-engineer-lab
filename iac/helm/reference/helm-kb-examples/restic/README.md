# restic backup runner (werf teaching tree)

**Business first:** object-storage backups need a clock that complains when snapshots go stale. Hub: [`../`](../).

I used this tree as the **Kubernetes runner** for restic to S3-compatible buckets. There is no `Chart.yaml`. Host Borg user/sudoers (same job class, different tool) lives in [`../../../../ansible/reference/ansible-backup-borg/`](../../../../ansible/reference/ansible-backup-borg/). This folder keeps the restic-user playbook and the S3/DMS packaging.

```text
restic/
  werf.yaml
  .helm/
    values.yaml
    secret-values.yaml.example
    conf/backup-monitoring.yaml
    templates/          # SSH + bucket Secrets, cron Deployment, VPA
  00-scripts/           # restic_backup_*.sh plus restic_run_on.sh
  ansible/              # restic-user.yaml + sudoers (copy authorized_keys.example)
  check_backups.py      # snapshot age + dead man's switch
  dms.py                # POST to dms.example.com
  schedule-staging
  schedule-production
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Multi-backend buckets | values list S3/MinIO-style endpoints per env; secrets stay in `secret-values.yaml.example` |
| `restic_run_on.sh` | Copy scripts, install restic, export per-bucket `RESTIC_*` / AWS keys, run the job |
| `check_backups.py` | Latest snapshot older than 24h raises; then a dead man's switch ping |
| Exception ConfigMap | Host / tag / path / backup-id mute list for the checker |

```bash
cp ansible/authorized_keys.example ansible/authorized_keys
cp vars.example vars
cp .helm/secret-values.yaml.example .helm/secret-values.yaml

cd ansible
ansible-playbook -bK -i mysql-prod-0.estate.example.com, restic-user.yaml

# restic_run_on.sh <host> <bucket_object_from_values> <script> [args]
./00-scripts/restic_run_on.sh 10.10.20.11 backup_bucket_postgresql_production_backup \
  restic_backup_postgres_stdout.sh 'POSTGRESQL-PRODUCTION --user postgres --do-su-under-user'
```

Do not pass wildcards as restic paths if the checker must match a stable Path set. Prefer a directory or a single file.

Dead man's switch names in `values.yaml` (`backup_dms.name`) must match the monitoring point. `stagelong` is a named check (`backup-monitoring-restic-stage-long`) without a `schedule-stagelong` file in this teaching tree (staging + production schedules only). Keys live in the secret overlay: copy `.helm/secret-values.yaml.example` to `.helm/secret-values.yaml` and merge the `CHANGE_ME` values before render.

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

**Keywords:** restic, S3, werf, dead man's switch, backup, SSH
