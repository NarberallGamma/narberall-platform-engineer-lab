# Estate cluster monitoring overlay

I ran Grafana, Prometheus, and OpenObserve in-cluster on a Huawei-class CCE estate. This folder is the **overlay I wrote**: provisioned alerts, dashboard JSON I kept as artefacts, two custom cloud exporters, and an OpenObserve log collector. Upstream Grafana / Prometheus / OpenObserve / blackbox / node-exporter chart trees stay out of git.

Host VictoriaMetrics / Grafana / node-exporter is a second layer. I do not duplicate it here. Ansible: [`../../../../ansible/`](../../../../ansible/). Hub: [`../`](../). Manager page: [`../../../../../architecture/05-sre.md`](../../../../../architecture/05-sre.md). Catalog: [`../../../../../docs/sre/`](../../../../../docs/sre/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used the **Grafana HTTP API** the same way I use Vault or Argo: new folders and dashboards the day a product grew, then keep the JSON next to the chart. Alert groups in this folder are what Helm provisions (`alerting:` map). Sidecar dashboards are off, so the JSON under `grafana/dashboards/` is the artefact I edited, not a silent mount. CloudEye and cloud-status exporters are small HTTP clients so managed Kafka / RDS / emergency work land in the same Grafana.

## Copy vs document

| Path | In git | Why |
|------|--------|-----|
| `grafana/alerts/*.yaml` | copy | Provisioned rules, contact points, policies, templates |
| `grafana/dashboards/*.json` | copy | Artefacts. Sidecar is **off**, so Helm does not load these JSON files |
| `grafana/templates/external-secret-smtp.yaml` | copy | SMTP username/password from Vault via ESO |
| `grafana/values.example.yaml` | excerpt | Alerting map, Prometheus datasource, Recreate+PVC, Istio inject, SMTP secret name |
| Grafana vendor `templates/` / `charts/` | document | helm 10.4.0 / app 12.3.0. Not vendored |
| `exporters/prometheus-cloudeye-exporter/` | copy | Custom CloudEye chart (RDS/DCS/DMS scrape) |
| `exporters/prometheus-cloud-ru-status-exporter/` | copy | Custom Cloud.ru status/emergency exporter |
| blackbox / node-exporter charts | document | Vendored upstream. Not copied |
| `prometheus/` | document | kube-prometheus-stack 27.50.1 values only in NOTES (scrape topology, 350Gi; kube-state/node subcharts off) |
| `openobserve-collector/` | copy | Custom DaemonSet. CCE hostPath `container_logs` mounted at `/var/log/pods` |
| `openobserve/README.md` + `values.example.yaml` | document + excerpt | Chart 0.70.1. HA 2x, 60d retention, NATS on, dex off. Vendor templates not copied |

## Alerting map keys

Sidecar alerts are off. Grafana chart `alerting:` points at files in `grafana/alerts/`. Keys I used:

| Key | Role |
|-----|------|
| `estate-ledger-global.yaml` | Ethereum / TRON block lag |
| `estate-databases-global.yaml` | SQL stale-balance and failed on-chain rows |
| `cloud-ru-global-alerts.yaml` | Cloud.ru emergency / planned work |
| `kafka-dms-cloudeye.yaml` | DMS consumer lag and broker CPU/RAM |
| `postgresql-rds-cloudeye.yaml` | RDS CloudEye |
| `strimzi-kafka-connect.yaml` | Connect CPU/JVM per pod |
| `kubernetes-cce-alerts.yaml` | API server, CoreDNS, namespaces, PVC |
| `kubernetes-views-pods-resources.yaml` | Pod CPU/memory vs limits |
| `node-exporter-host.yaml` | Host and disk |
| `platform-grafana-email-contactpoint.yaml` | SMTP contact points (admins + ops) |
| `notification-templates.yaml` | Telegram HTML + plain-text mail |
| `notification-policies.yaml` | Dual delivery, grouping, 4h / 48h repeat |

Prometheus datasource UID in rules: `PBFA97CFB590B2093`. Contact points: **Platform Grafana Alerts** (Telegram, existing in UI), **Platform Grafana Email (admins)** and **(ops)**. SMTP Kubernetes secret name: `grafana-smtp-vault-secrets`.

## Dashboard names (artefacts)

Sidecar dashboards are off (`dashboards: {}`). JSON under `grafana/dashboards/` is what I kept next to the chart, not what Helm mounts.

| File | Title |
|------|-------|
| `estate-ledger-global.json` | Estate / Ledger / Global |
| `estate-databases-global.json` | Estate / Databases / Global |
| `cloud-ru-global.json` | Cloud.ru / Global |
| `strimzi-kafka.json` | Kafka (DMS) - CloudEye |
| `strimzi-kafka-connect.json` | Strimzi Kafka Connect |
| `postgresql.json` | PostgreSQL (RDS) - CloudEye |
| `spring-boot-2.1-system-monitor.json` | Spring Boot 2.1 System Monitor |
| `node-exporter-full.json` | Node Exporter Full |
| `k8s-system-api-server.json` | Kubernetes / System / API Server |
| `k8s-system-coredns.json` | Kubernetes / System / CoreDNS |
| `k8s-views-global.json` | Kubernetes / Views / Global |
| `k8s-views-namespaces.json` | Kubernetes / Views / Namespaces |
| `k8s-views-nodes.json` | Kubernetes / Views / Nodes |
| `k8s-views-pods.json` | Kubernetes / Views / Pods |

## Two-layer observability

| Layer | Where |
|-------|--------|
| In-cluster overlay | this folder |
| Host scrape / VictoriaMetrics / host Grafana | [`../../../../ansible/`](../../../../ansible/) |

**Keywords:** Grafana alerting, Grafana HTTP API, CloudEye, Cloud.ru, OpenObserve collector, CCE hostPath, External Secrets, Istio inject, Recreate PVC
