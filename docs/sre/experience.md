# Monitoring experience

I stand the path up and keep it useful on call. The stack is not a logo list. Each line below is something I have **installed, wired, queried, and used in an incident**.

Six-year narrative (domains, JVM, SLA): [`../experience.md`](../experience.md). Manager page: [`../../architecture/05-sre.md`](../../architecture/05-sre.md).

## Metrics

| Product | How I used it | Proof in this lab |
|---------|---------------|-------------------|
| **Prometheus** + **Alertmanager** | Scrape jobs, Kubernetes SD, blackbox, inhibits, Telegram / mail | [`../../iac/ansible/reference/ansible-app-platform/`](../../iac/ansible/reference/ansible-app-platform/) `monitoring_deploy` |
| **VictoriaMetrics** + **vmalert** | remote_write from host Prom, long retention, PromQL | [`../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/`](../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/) |
| **Grafana** | Folders, dashboards, provisioned `alerting:` map, contact points, notification policies. HTTP API the same day a product grows | Overlay: [`../../iac/helm/reference/helm-estate-cluster/monitoring/grafana/`](../../iac/helm/reference/helm-estate-cluster/monitoring/grafana/) (**14** JSON, **12** alert YAML) |
| **node-exporter** | `:9100` on estate VMs; TLS watch next to it | [`../../iac/ansible/reference/ansible-estate/`](../../iac/ansible/reference/ansible-estate/); images [`../../iac/docker/images/operators/cert-monitoring/`](../../iac/docker/images/operators/cert-monitoring/), [`../../iac/docker/images/operators/cert-orchestrator/`](../../iac/docker/images/operators/cert-orchestrator/) (compose sits next to that image), [`../../iac/docker/images/operators/hibernate/`](../../iac/docker/images/operators/hibernate/) |
| **blackbox** / **cAdvisor** | Probe and container scrape on the host Prom | app-platform `monitoring_deploy` |
| **CloudEye** / cloud status | Custom exporters so managed Kafka / RDS / emergency work land in Grafana | Charts [`../../iac/helm/reference/helm-estate-cluster/monitoring/exporters/`](../../iac/helm/reference/helm-estate-cluster/monitoring/exporters/) **and** images [`../../iac/docker/images/operators/cloud-metrics/`](../../iac/docker/images/operators/cloud-metrics/) (Dockerfile only) and [`../../iac/docker/images/operators/cloud-status/`](../../iac/docker/images/operators/cloud-status/) |
| **EDR coverage** | AD + cloud inventory + vendor EDR into Prometheus on the cybersec VM | [`../../iac/docker/compose/sec-stack/`](../../iac/docker/compose/sec-stack/) pins [`../../iac/docker/images/operators/edr-coverage/`](../../iac/docker/images/operators/edr-coverage/) (`vendor-edr.py`) |
| **CustomPrometheusRules** | Deckhouse CRs I maintained (CNPG, Redis, Cilium, ES, ingress) | [`../../iac/helm/reference/helm-addons-extra/custom-prometheus-rules/`](../../iac/helm/reference/helm-addons-extra/custom-prometheus-rules/) (**12** templates) |
| **sysstat / vnstat** | Host before a full Prom estate | [`../../iac/ansible/reference/monitoring-starter/`](../../iac/ansible/reference/monitoring-starter/) |
| **Zabbix** | Same habit on estates that already had it | Named in [`../experience.md`](../experience.md); not a second dump |

## Logs

| Product | How I used it | Proof in this lab |
|---------|---------------|-------------------|
| **OpenObserve** + collector | Ingest, retention, saved log views. Custom DaemonSet on CCE hostPath | [`../../iac/helm/reference/helm-estate-cluster/monitoring/openobserve-collector/`](../../iac/helm/reference/helm-estate-cluster/monitoring/openobserve-collector/) |
| **ELK / OpenSearch** + **Logstash** / Filebeat | Index patterns, L2 saved queries | [`../../iac/helm/reference/helm-addons-extra/elk/`](../../iac/helm/reference/helm-addons-extra/elk/) |
| **ECK** | Operator overlay | addons-extra ECK |
| **ElastAlert2** + **Falco** | Runtime **log** alerts on Elasticsearch | [`../../iac/helm/reference/helm-addons-extra/elastalert2/`](../../iac/helm/reference/helm-addons-extra/elastalert2/) |
| **Loki** / Promtail / Vector / Fluent Bit | Estates that already picked Loki | Experience; not a second vendor tree here |
| **Graylog** | Same habit where it was already the log plane | [`../experience.md`](../experience.md) |

## Traces

| Product | How I used it | Proof in this lab |
|---------|---------------|-------------------|
| **Jaeger** | Trace search when the shop estate did not pick Istio | [`../../iac/helm/reference/helm-data-plane/`](../../iac/helm/reference/helm-data-plane/) |
| **OpenTelemetry Collector** | Shop-class collector chart + Operator CR | [`../../iac/helm/reference/helm-addons-extra/opentelemetry-collector/`](../../iac/helm/reference/helm-addons-extra/opentelemetry-collector/) |
| Zipkin-class | Same instinct: follow the request, not 50 log greps | Experience |

## What "I used the API" means

Almost every product above has an HTTP API. I used those APIs the way a developer uses a backend: create and edit **views**, folders, datasources, contact points, alert groups; search logs; open a saved query for L2. Git is the source of truth when Helm provisions Grafana. The API is how I move **fast** between upgrades: a new Kafka lag view, a CloudEye RDS panel, a CCE API-server row, a Spring Boot JVM board. Same day, not a ticket to a monitoring vendor.

Scripts and agents that call those APIs: [`../../architecture/06-product-apis.md`](../../architecture/06-product-apis.md). Tokens and Vault: [`../security-ai.md`](../security-ai.md).
