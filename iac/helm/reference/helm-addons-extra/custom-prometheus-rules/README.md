# Custom PrometheusRules (Helm / werf-raw)

**Business first:** the alerting pack is **rules I maintained**, not a vendor defaults dump. I edited PromQL through git and the Prometheus / VictoriaMetrics HTTP APIs the same day a product needed a new threshold. Hub: [`../`](../). Manager page: [`../../../../../architecture/05-sre.md`](../../../../../architecture/05-sre.md). Catalog: [`../../../../../docs/sre/metrics.md`](../../../../../docs/sre/metrics.md). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

Deckhouse `CustomPrometheusRules` (no Chart.yaml). Werf deploys the templates as-is. Some groups are gated on `werf.env` (dev vs production). Log alerts are the ElastAlert2 slice next door; this pack is PromQL.

```text
custom-prometheus-rules/
  werf.yaml
  .gitlab-ci.yml
  .helm/templates/
    aws.yaml                  # S3 replication + CloudWatch billing (dev)
    cnpg_alerts.yaml          # CloudNativePG memory, WAL, deadlocks, PVC
    cilium_alerts.yaml        # d8-cni-cilium restarts / OOM
    elasticsearch.yaml        # cluster red/yellow, heap, disk watermark
    httpresponses.yaml        # ingress 429 thresholds
    redisCluster.yaml         # known nodes vs replicas (production)
    main_alerts.yaml          # PVC, RabbitMQ depth, OOMKilled, 499/500
    limitsfinder.yaml         # CPU request vs usage, memory vs limit
    nodescpula.yaml           # node CPU busy
    PodContainerRestart.yaml
    PodReadinessStatus.yaml   # delivery-scheduler, promo-api, calculator
    differentreleases.yaml    # helm release drift vs a second region
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| No Chart.yaml | Werf-raw CustomPrometheusRules, same habit as the Borg backup slice |
| CNPG | Ten rules on `.*app.*` namespaces: memory, swap, WAL, connections |
| Redis cluster | Full-mesh node count and replica count == 2 |
| AWS | Failed/pending S3 replication; billing delta only on `dev` |
| Cilium | Restarts and OOM in `d8-cni-cilium` |
| Cross-region | `differentreleases` compares helm annotations vs `production-use1` |
| Deckhouse PLK | `plk_markup_format`, grouping keys, Grafana runbook links |

## Env gating

Werf plucks `werf.env`. Files without a gate render on every env.

| Template | When it renders |
|----------|-----------------|
| `cnpg_alerts.yaml` | `dev` only |
| `aws.yaml` | always; `AWSBillingCostIncrease` only on `dev` |
| `redisCluster.yaml` | `production` only |
| `PodReadinessStatus.yaml` | `production` only |
| `differentreleases.yaml` | `production` only |
| `nodescpula.yaml` | every env except `dev` |
| Remaining six templates | every env |

Namespaces in matchers are `production|shop|lab` (generic). Grafana links are `https://grafana.example.com`.

**Keywords:** PrometheusRules, Deckhouse, CloudNativePG, Redis, Cilium, Elasticsearch, AWS, werf
