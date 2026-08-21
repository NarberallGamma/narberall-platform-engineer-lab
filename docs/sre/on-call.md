# On-call, exporters, same-day views

The SRE loop is the Cisco-style seven-step I already use on incidents: define, gather (metrics + logs + traces + last change), analyze, eliminate, test a small knob, document. Education: [`../experience.md#education`](../experience.md#education).

## Exporters I actually shipped

| Exporter | Path | Why it exists |
|----------|------|---------------|
| node-exporter | [`../../iac/ansible/reference/ansible-estate/`](../../iac/ansible/reference/ansible-estate/) | Host disk, CPU, filesystem on Huawei-class ECS |
| Prometheus CloudEye | Chart [`../../iac/helm/reference/helm-estate-cluster/monitoring/exporters/prometheus-cloudeye-exporter/`](../../iac/helm/reference/helm-estate-cluster/monitoring/exporters/prometheus-cloudeye-exporter/) **and** [`../../iac/docker/images/operators/cloud-metrics/`](../../iac/docker/images/operators/cloud-metrics/) Dockerfile | Managed RDS / DCS / DMS is otherwise a blind spot |
| Cloud.ru status | Chart [`../../iac/helm/reference/helm-estate-cluster/monitoring/exporters/prometheus-cloud-ru-status-exporter/`](../../iac/helm/reference/helm-estate-cluster/monitoring/exporters/prometheus-cloud-ru-status-exporter/) **and** [`../../iac/docker/images/operators/cloud-status/`](../../iac/docker/images/operators/cloud-status/) Dockerfile | Emergency / planned work into Grafana |
| PAN-OS / EDR (host) | [`../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/`](../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/) **and** [`../../iac/docker/images/operators/edr-coverage/`](../../iac/docker/images/operators/edr-coverage/). Compose [`../../iac/docker/compose/sec-stack/`](../../iac/docker/compose/sec-stack/) pins the image | Cybersec VM scrape, not the cluster overlay |
| blackbox / cAdvisor | app-platform `monitoring_deploy` | Probe and container metrics on the host Prom |

Those CloudEye and status exporters are **not** a vendor Grafana tree. CloudEye is a Dockerfile I pin (`src/` stays out). Status is a small HTTP client I wrote and keep in git. They scrape a public or estate API and expose Prometheus metrics Grafana already knows how to panel.

## Paging decisions

| Rule | Why |
|------|-----|
| `noDataState: OK` on metric alerts | A scrape timeout is not a product outage. Page when the query returns a value and the threshold fires |
| Dual delivery | Telegram + mail on the overlay; Alertmanager routes on the host stack |
| Grouping / repeat | 4h / 48h on the provisioned policies. Noise gets bypassed |
| Host vs cluster | Node-exporter is scraped by Ansible Prom. Overlay alerts **on** those series |

## Same-day view (how it actually happens)

1. Product grows (new Kafka consumer, new RDS, new JVM service).
2. I add a folder and a dashboard through the **Grafana HTTP API**, or a PromQL rule through git + Prometheus / VM API.
3. I land the YAML / JSON in the overlay (`grafana/alerts/`, `grafana/dashboards/`) on the next chart upgrade.
4. If Helm is not the path (host Grafana), the same edit is a file in the Ansible / SOPS tree.

Agents may call those APIs only after the trust model in [`../security-ai.md`](../security-ai.md). Scripts first: [`../../architecture/06-product-apis.md`](../../architecture/06-product-apis.md).

## Cases

- [Case 11](../../case-studies/11-helm-estate.md): overlay volume and GitOps door
- [Case 10](../../case-studies/10-ansible-estate.md): host scrape siblings
- [Case 12](../../case-studies/12-docker-images.md): operator images and sec-stack compose
- [Case 01](../../case-studies/01-ai-llm-platform.md): private GPU API next to n8n / JSM inventory (not a metrics stack, same API habit)
