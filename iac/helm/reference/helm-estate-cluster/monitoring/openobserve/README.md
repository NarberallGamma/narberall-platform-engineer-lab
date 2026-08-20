# OpenObserve (in-cluster)

I ran OpenObserve HA in namespace `monitoring` from [openobserve-helm-chart](https://github.com/openobserve/openobserve-helm-chart) **0.70.1** (`public.ecr.aws/zinclabs/openobserve-enterprise:v0.70.1`). Vendor `templates/` (dozens of files) are **not** in this lab. Pin and keys: `values.example.yaml`.

Collector that tails CCE container logs: [`../openobserve-collector/`](../openobserve-collector/).

## What I changed vs upstream

| Knob | Estate setting |
|------|----------------|
| HA | `replicaCount` router / ingester / querier **2** |
| Retention | `config.ZO_COMPACT_DATA_RETENTION_DAYS` **60** |
| NATS | `nats.enabled: true` (JetStream PVC) |
| Dex | `enterprise.dex.enabled: false` |
| Object store | external OBS-class bucket (MinIO off) |
| Metadata | external Postgres RDS DSN from Vault, not in git |
| Ingress | `openobserve.example.com`, TLS `wildcard-tls` |

Org identifier and ingest tokens stay out. ESO maps Vault `secret/openobserve` to Secret `openobserve-vault-secrets` (`envFrom` on pods). Non-secret S3 bucket/endpoint/region belong in `config.ZO_S3_*`.

## Streams (names from the collector)

| Namespace | Stream | Group |
|-----------|--------|-------|
| estate-app | `ns_estate_app` | app |
| kafka | `ns_kafka` | infra |
| istio-system | `ns_istio_system` | infra |
| ingress-nginx | `ns_ingress_nginx` | infra |
| external-secret-manager | `ns_external_secret_manager` | infra |
| argocd | `ns_argocd` | infra |
| monitoring | `ns_monitoring` | infra |

Filter on **`k8s_app`**. `service_name` is often just `application`. I leave `_timestamp` out of saved-view selectedFields (duplicate time column). Logs only; metrics/traces stay off so ingest stays inside the enterprise daily cap.

WAL lives on PVC (`storageClass: ssd`). Compactor ships Parquet to object store. A stream with `data_retention = 0` inherits the 60-day default.

## Install shape

```bash
# vendor chart is fetched separately (not in this overlay)
helm upgrade --install openobserve <upstream-openobserve-chart> -n monitoring \
  -f values.example.yaml
```

Vendor `templates/` + full values are not in this overlay. The excerpt is the list of keys I actually set.
