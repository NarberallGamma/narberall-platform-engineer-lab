# Webapps (werf-raw PHP)

**Business first:** the widgets API is a **werf chart without Chart.yaml**, not a Laravel compose file. Parent: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I kept `werf.yaml` and `.helm/` only. Application PHP stays out. Werf builds nginx, PHP-FPM (`app`), a one-job cron image, and a MySQL client image used by hook Jobs.

```text
webapps/
  werf.yaml
  .gitignore
  .helm/
    values.yaml
    secret-values.example.yaml
    templates/
      _flant_lib.tpl          # fl.value / env-pluck helpers
      _helper.tpl             # ingress aliases, affinity
      _resources.tpl
      _newrelic.tpl
      05-cm-nginx.yaml
      05-cm-crons.yaml
      05-cm-scripts.yaml      # create-db / wait-db (non-prod)
      15-envs.yaml            # ConfigMap + Secret from values
      20-webapps.yaml         # nginx+php Deployment, headless Service, VPA, PDB
      21-webapps-worker.yaml  # queue:work
      25-webapps-crons.yaml   # supercronic, all schedules
      26-webapps-crons-one-job.yaml
      10-job-create-db.yaml   # helm hook, skipped in production
      30-job-migrations.yaml
      90-ingress.yaml         # wildcard hosts + cert-manager Certificate
      feature-tests.yaml      # helm hook, test env only
```

```bash
cp .helm/secret-values.example.yaml .helm/secret-values.yaml
# fill CHANGE_ME, then:
# werf render --env stage
# werf converge --env stage
```

`werf.env` and `global.cluster` (`east` / `west`) select hosts, replica counts, and MySQL Service names through `fl.value` and `pluck`.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| No Chart.yaml | Werf-raw. `.Chart.Name` comes from `project: webapps` |
| Two clusters in values | Same templates, different URL maps and MySQL masters |
| Two cron Deployments | Shared crontab ConfigMap. Second image swaps Laravel Kernel to a single job |
| Hook Jobs | create-db (non-prod), migrate after wait-db, phpunit on test |
| Ingress + Certificate | Wildcard hosts, `www` aliases, cert-manager issuer |
| Checksum annotations | nginx ConfigMap and env Secret roll the pods |
| VPA `Off` + PDB | Request hints without autoscaler writes |

## Secrets

Encrypted `secret-values.yaml` stays out of git. Example file lists mysql passwords, New Relic license, `APP_KEY`, billing, Slack, Stripe, and mail keys as `CHANGE_ME`. Access key id sat in the ConfigMap values in the source tree; I left that key in `values.yaml` as `CHANGE_ME` so the split is visible.

## What is not in git

- Application source, `.werffiles`, composer lock
- Live `secret-values.yaml` and `.werf_secret_key`
- GitLab CI
- Two thinner sibling PHP trees (same packaging, fewer templates)

**Keywords:** werf, PHP-FPM, nginx, supercronic, MySQL, cert-manager, New Relic, VPA
