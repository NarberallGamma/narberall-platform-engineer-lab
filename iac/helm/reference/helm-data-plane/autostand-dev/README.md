# DEV autostand (Helm sample)

**Business first:** a disposable in-cluster Kafka / Postgres / MinIO stand used to spin a shop sandbox. This is a **contrast** to the estate kit ([`../../helm-estate-cluster/`](../../helm-estate-cluster/)), where production brokers and databases were **managed** (Strimzi-operated Connect on an external Kafka, RDS for Postgres). It is **not** a second production Kafka kit.

Parent kit: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

Three tiny custom charts plus one shared NodePort values file. Roles, clone Jobs, and CI stay out.

## Copied (8 files)

| Path | Role |
|------|------|
| `kafka/Chart.yaml` | Chart name `kafka` 1.0.0 |
| `kafka/templates/kafka.yml` | KRaft single-node broker, kafka-ui, NodePort, PVC |
| `postgres/Chart.yaml` | Chart name `postgres` 1.0.0 |
| `postgres/templates/postgres.yml` | Postgres 15, init ConfigMap, NodePort, PVC |
| `minio/Chart.yaml` | Chart name `minio` 1.0.0 |
| `minio/templates/minio.yml` | MinIO + bucket-init Job, API/UI NodePorts, PVC |
| `values-sample.yaml` | Shared `nodePorts` map (one overlay for all three charts) |
| this README | Contrast + copy vs NOTES |

```text
helm template kafka ./kafka -f values-sample.yaml
helm template postgres ./postgres -f values-sample.yaml
helm template minio ./minio -f values-sample.yaml
```

Each render shows Deployment + Service + PVC (MinIO also a Job; Kafka also kafka-ui).

## NOTES (not copied)

| Source | Why it stays out |
|--------|------------------|
| `roles/` | Tiny RoleBinding of named ServiceAccounts. Not unique (generic `edit`) and held personal account names |
| `postgres-clone.yml` | Job with a live source host and a plaintext DB password |
| `s3-clone.tmpl.yml` | rclone Job with live object-store endpoints and shop bucket filters |
| `environments/ci/` and GitLab CI | Pipeline to create namespaces and install these charts. Not the chart shape |
| Environments README | Live Node IPs and default passwords |
| Strimzi / Bitnami Kafka vendor charts | Estate production path. See [`../../helm-estate-cluster/`](../../helm-estate-cluster/) NOTES |
| Zalando / RDS operator trees | Estate data path. This stand is a single Deployment |

## Pin

| Chart | Image | Shape |
|-------|-------|-------|
| kafka | `apache/kafka:3.7.2`, `provectuslabs/kafka-ui:latest` | KRaft broker+controller, RF=1, PLAINTEXT |
| postgres | `postgres:15` | `max_connections=10000`, one init database |
| minio | `minio/minio:RELEASE.2025-09-07T16-13-09Z`, `minio/mc:latest` | Server + console 9001, many shop-shaped test buckets |

Cloud CSI annotations in the source material (`volume-type`, volume-name prefix) are rewritten to `storage.example.com/*`. Storage class is `example-block`.

## Why this is not the estate Kafka story

| | This folder | Estate kit |
|--|-------------|------------|
| Broker | One in-cluster KRaft Deployment | Managed / external broker. Helm owns Connect + connectors |
| Postgres | One in-cluster Deployment | Production data on RDS. Zalando is a DEMO path only |
| Object store | In-cluster MinIO + init Job | Contrast only. Operator install lives under addons |
| Audience | Per-branch sandbox | Production envelope |

**Keywords:** autostand, Kafka KRaft, PostgreSQL, MinIO, NodePort, contrast sample
