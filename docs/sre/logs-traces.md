# Logs and traces

Metrics page a threshold. Logs and traces explain **why**. I keep those planes next to metrics, not as a later project.

## OpenObserve (CCE overlay)

Custom collector DaemonSet: [`../../iac/helm/reference/helm-estate-cluster/monitoring/openobserve-collector/`](../../iac/helm/reference/helm-estate-cluster/monitoring/openobserve-collector/).

CCE hostPath `container_logs` is mounted at `/var/log/pods`. The vendor OpenObserve chart tree is **not** copied. Pin and HA notes (chart 0.70.1, 2x, 60d retention, NATS on, dex off) live in the overlay `openobserve/` README + values excerpt.

I used the OpenObserve HTTP API for ingest checks, retention, and saved log views. Same-day habit as Grafana folders.

## ELK / ECK / ElastAlert2

| Piece | Path | Job |
|-------|------|-----|
| ELK | [`../../iac/helm/reference/helm-addons-extra/elk/`](../../iac/helm/reference/helm-addons-extra/elk/) | Elasticsearch / Kibana-class logging on estates that picked ELK |
| ECK | addons-extra ECK overlay | Operator, not a hand YAML cluster |
| ElastAlert2 + Falco | [`../../iac/helm/reference/helm-addons-extra/elastalert2/`](../../iac/helm/reference/helm-addons-extra/elastalert2/) | Runtime **log** rules on ES. Distinct from sec-stack metrics |

I add and edit ElastAlert / Kibana views through the ES HTTP API. Falco / Suricata-class events land in the same store. This is **not** the Grafana `alerting:` map and **not** host VictoriaMetrics.

## Traces

| Piece | Path | When I used it |
|-------|------|----------------|
| Jaeger | [`../../iac/helm/reference/helm-data-plane/`](../../iac/helm/reference/helm-data-plane/) | Shop estate that did not pick Istio |
| OTel Collector | [`../../iac/helm/reference/helm-addons-extra/opentelemetry-collector/`](../../iac/helm/reference/helm-addons-extra/opentelemetry-collector/) | Collector chart + Operator CR |

Fifty-plus microservice estates need correlation. "User cannot pay" is not fifty log greps. Traces plus a broker lag panel (metrics) is the usual pair.

## What stays out of git

Vendor Elasticsearch / Kibana / Jaeger / OO **trees**. Loki / Graylog estates are experience ([`experience.md`](experience.md)), not a second dump. Tenant log samples stay private.
