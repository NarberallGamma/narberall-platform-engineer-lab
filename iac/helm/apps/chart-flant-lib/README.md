# Catalog API (Chart + flant-lib)

**Business first:** this PHP API is a **werf chart** that pulls **flant-lib** for env-keyed values. Helpers stay a pin. I do not vendor the tarball.

Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Sibling with a local subchart: [`../chart-local-subchart/`](../chart-local-subchart/).

I used this packaging when a catalog API needed Deckhouse `fl.value` / `fl.isTrue` maps (`_default`, `preprod`, `prodlike`, `production`) without copying the library into `templates/`. `helm dependency build` pulls flant-lib **1.1.1** from the public Flant repo. The 7 KB `flant-lib-1.1.1.tgz` stays out of git.

```text
chart-flant-lib/
  werf.yaml                              # image contract: php, nginx, exporter, init, postgres, cron
  .gitignore
  .helm/
    Chart.yaml                           # catalog-api; depends on flant-lib ~1
    requirements.lock                    # flant-lib 1.1.1 pin
    values.yaml
    secret-values.example.yaml
    schedules/crontab
    templates/
      _helpers.tpl                       # init-psql + scheduling snippets
      10-deploy-app.yaml                 # nginx + php-fpm + exporter, VPA off, PDB
      20-nginx-conf.yaml
      30-app-envs.yaml                   # Secret from envs.config via fl.value
      40-php-conf.yaml
      50-job-migrations.yaml             # phinx, weight -100
      70-ingress.yaml                    # public /api /places + optional Certificate
      80-cron-conf.yaml
      90-deploy-cron.yaml
      postgres/postgres.yaml             # review StatefulSet, off in production
      rabbitmq/cr.yaml                   # Vhost/User/Permission on a shared cluster
```

Render (after `helm dependency build` in `.helm/`):

```bash
export WERF_ENV=preprod
werf render --dev --values=.helm/values.yaml --secret-values=.helm/secret-values.yaml
```

## Who this page is for

Hiring lead: this is the Chart + remote library SAMPLE, not a second copy of the orders app. Engineer: `fl.value` is the env switch. Workload objects stay in this chart.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Remote flant-lib | Chart.yaml + requirements.lock 1.1.1. No vendored `charts/*.tgz` |
| Env-keyed values | `pluck` / `fl.value` for replicas, hosts, resources, nodeSelector |
| In-cluster Postgres | StatefulSet + Service + VPA/PDB for review and prodlike. Production points at Patroni |
| Shared RabbitMQ operator | This chart does not create the cluster. It adds vhost, policy, user, and permissions on `orders-rmq` |
| Ingress split | Three Ingress objects on one host: `/`, `/api` (office CIDR), `/places` (search CIDR) |
| Deckhouse reloader | `pod-reloader.deckhouse.io/auto` on the Deployment |
| Cron | supercronic + ConfigMap from `schedules/crontab` |
| Migrate Job | `werf.io/weight: "-100"` after `init-psql` |

## What this chart is not

- Not the orders app with a local Postgres subchart.
- Not a snapshot clone of an older API tree.
- Not a Bitnami or RabbitMQ operator install chart.
- Not Argo Application manifests.

## Vendor charts (documented, not vendored)

| Chart | Pin | What I changed | In git |
|-------|-----|----------------|--------|
| flant-lib | **1.1.1** (`~1` in Chart.yaml) | Env maps in values; templates call `fl.value` / `fl.isTrue` | Chart.yaml + requirements.lock. `.tgz` stays out |

`helm dependency build` pulls 1.1.1 from `https://charts.flant.com/common/github`.

## Secrets

Copy `.helm/secret-values.example.yaml` to `.helm/secret-values.yaml`. `.gitignore` keeps `secret-values.yaml`, `.werf_secret_key`, and vendor `.tgz` out of git. DB, JWT, RabbitMQ, and Telegram fields stay out of git.

## Sanitize

Hosts are `*.example.com`. Patroni is `pg-patroni.example.svc`. Ingress allow-lists use documentation CIDRs (`203.0.113.0/24`, `2001:db8::/32`) plus RFC1918. Node role is `node-role/app`. Passwords are `CHANGE_ME`.

**Keywords:** Helm, flant-lib, werf, PHP-FPM, nginx, PostgreSQL, RabbitMQ operator, Deckhouse, ingress-nginx
