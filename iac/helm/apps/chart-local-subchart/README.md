# Orders app (Chart + local subchart)

**Business first:** this orders API is a **werf chart** with a **small local Postgres subchart**. I wrote `charts/common-postgresql` (six files). I do not vendor a Bitnami tree.

Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Sibling that uses remote flant-lib: [`../chart-flant-lib/`](../chart-flant-lib/).

I used this packaging when review needed three in-cluster Postgres instances and production needed Endpoints to an external pooler. The parent Chart.yaml depends on `common-postgresql` as alias `postgresql` with `export-values` for `werf`. Helpers for `fl.value` live in `templates/_flant_lib.tpl` (a local copy). Chart.lock still records an old flant-lib 1.1.1 pin; Chart.yaml no longer lists that remote chart.

```text
chart-local-subchart/
  werf.yaml                              # image contract: backend, frontend, postgres, rabbitmq, exporter, init
  .gitignore
  .helm/
    Chart.yaml                           # orders-app; local common-postgresql only
    Chart.lock                           # leftover flant-lib 1.1.1 pin (helpers are local)
    requirements.lock                    # common-postgresql ~0
    values.yaml
    secret-values.example.yaml
    charts/common-postgresql/            # 6 files: clusters + external Endpoints
    templates/
      _flant_lib.tpl                     # local fl.value / fl.isTrue
      _helpers.tpl
      _init_containers.tpl               # wait for RabbitMQ + three Postgres roles
      app.yaml                           # nginx + php-fpm + exporter
      app-config.yaml                    # ConfigMap + Secret from envs
      app-nginx-config.yaml
      app-php-config.yaml
      consumers.yaml                     # range over values.consumers
      ingress.yaml                       # shop + partners + public API
      job-migrations.yaml                # three phinx Jobs
      job-create-topology.yaml
      job-recreate.yaml                  # review only: seed SQL if tables missing
      rabbitmq/                          # RabbitmqCluster + DexAuthenticator
```

Render (local subchart is already under `charts/`):

```bash
export WERF_ENV=preprod
werf render --dev --values=.helm/values.yaml --secret-values=.helm/secret-values.yaml
```

## Who this page is for

Hiring lead: this is the Chart + local subchart SAMPLE. Engineer: Postgres objects come from `charts/common-postgresql`. The parent owns the app, consumers, migrate Jobs, and the RabbitMQ operator wrap.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Local subchart | `common-postgresql` 0.0.1, six files, alias `postgresql`, `export-values` for werf images |
| External Endpoints | Production `external_hosts` become Service + Endpoints (`10.10.x.x`) when in-cluster clusters are off |
| Three review DBs | `orders-delivery`, `history`, `report` StatefulSets. Production `enabled: false` |
| Local flant helpers | `_flant_lib.tpl` in the parent and again in the subchart. No `charts/*.tgz` |
| RabbitMQ operator | RabbitmqCluster + definitions ConfigMap + extra vhosts (`restaurant`, `kitchen`) via CRs |
| Dex on management UI | Ingress auth-url to a DexAuthenticator. Group `platform` |
| Two consumer Deployments | `commandConsume.php` and `eventConsume.php`, same init waits as the app |
| Three migrate Jobs | Root credentials override app users for phinx. `werf.io/weight: "-100"` |
| Review recreate Job | Runs only when `global.env` is `review`. Applies setup SQL if a relation is missing |

## What this chart is not

- Not the catalog API that depends on remote flant-lib.
- Not a Bitnami PostgreSQL or RabbitMQ helm tree.
- Not the PHP application, docker build, or shared GitLab CI includes.

## Local subchart (in git)

| Chart | Version | What it renders | In git |
|-------|---------|-----------------|--------|
| common-postgresql | 0.0.1 | StatefulSet + Service + NodePort + VPA/PDB per cluster; Service+Endpoints per `external_hosts` | six files under `charts/common-postgresql/` |

Parent values set `postgresql.enabled: true`. Cluster `enabled` flags still turn individual databases off in production.

## Leftover lock

`Chart.lock` lists flant-lib 1.1.1. That is a leftover from before helpers were copied into `_flant_lib.tpl`. `helm dependency build` against current Chart.yaml only records `common-postgresql`.

## Secrets

Copy `.helm/secret-values.example.yaml` to `.helm/secret-values.yaml`. DB passwords for three roles, RabbitMQ users, Sentry, SMS, and payment fields stay out of git.

## Sanitize

Hosts are `*.example.com`. External Postgres uses `10.10.0.11`, `10.10.0.12`, `10.10.0.20`. Ingress allow-lists use documentation CIDRs. Telegram chat ids and vendor logins are `CHANGE_ME`. Node role is `node-role/app`.

**Keywords:** Helm, local subchart, PostgreSQL, Endpoints, RabbitMQ operator, Dex, werf, PHP-FPM, Deckhouse
