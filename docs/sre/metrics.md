# Metrics: Grafana, Prometheus, VictoriaMetrics

Git is the source of truth when Helm provisions Grafana. The HTTP API is how I move between upgrades. Same-day work: a Kafka lag view, a CloudEye RDS panel, a CCE API-server row, a Spring Boot JVM board.

Manager page: [`../../architecture/05-sre.md`](../../architecture/05-sre.md). Overlay README (full file lists): [`../../iac/helm/reference/helm-estate-cluster/monitoring/`](../../iac/helm/reference/helm-estate-cluster/monitoring/).

## Grafana (in-cluster overlay)

| Kind | Path |
|------|------|
| Alert groups, contact points, policies | [`../../iac/helm/reference/helm-estate-cluster/monitoring/grafana/alerts/`](../../iac/helm/reference/helm-estate-cluster/monitoring/grafana/alerts/) |
| Dashboard JSON artefacts | [`../../iac/helm/reference/helm-estate-cluster/monitoring/grafana/dashboards/`](../../iac/helm/reference/helm-estate-cluster/monitoring/grafana/dashboards/) |
| SMTP via ESO | `grafana/templates/external-secret-smtp.yaml` in that tree |
| Values excerpt | `grafana/values.example.yaml` |

Sidecar dashboards and sidecar alerts are **off**. Helm copies the `alerting:` map into provisioning. The JSON under `dashboards/` is what I edited and kept next to the chart, not a silent mount.

Groups I provisioned (names only; YAML in git):

- Estate ledger / databases (block lag, stale SQL, failed on-chain rows)
- Cloud.ru emergency / planned work
- Kafka DMS CloudEye (consumer lag, broker CPU/RAM)
- PostgreSQL RDS CloudEye
- Strimzi Kafka Connect (CPU/JVM)
- Kubernetes CCE (API server, CoreDNS, namespaces, PVC)
- Pod CPU/memory vs limits
- Host / disk (`node-exporter-host`)
- Dual delivery: Telegram + mail, 4h / 48h repeat

Dashboard artefacts include estate ledger/databases, Cloud.ru global, Kafka / Connect, RDS PostgreSQL, Spring Boot 2.1, Node Exporter Full, and Kubernetes views (API server, CoreDNS, global, namespaces, nodes, pods).

## Prometheus / VictoriaMetrics (host)

| Piece | Path |
|-------|------|
| Scrape + remote_write | [`../../iac/ansible/reference/ansible-app-platform/`](../../iac/ansible/reference/ansible-app-platform/) role `monitoring_deploy` |
| VM + Grafana + vmalert | [`../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/`](../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/) |
| PromQL on Deckhouse | [`../../iac/helm/reference/helm-addons-extra/custom-prometheus-rules/`](../../iac/helm/reference/helm-addons-extra/custom-prometheus-rules/) |

I query Prom / VM for silences and recording rules the same way I edit Grafana. A scrape gap must not page (`noDataState: OK` on metric rules). Notify when the query returns a value and the threshold fires.

## Host Grafana vs overlay Grafana

They are **both** real. Host Grafana sits on the cybersec VM (sec-stack). Overlay Grafana is the CCE package. Do not collapse them. Layer map: [`layers.md`](layers.md).
