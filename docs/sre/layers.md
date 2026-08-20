# Complementary layers

Multiple observability planes. **Do not merge** them into one compose or one chart. Host cybersec metrics stay on a VM. The CCE overlay is Grafana + exporters + an OpenObserve collector. PromQL packs, ElastAlert2, ELK, and OTel are other-estate addons.

Hub table (same split): [`../../iac/helm/README.md#observability-split-do-not-duplicate-ansible`](../../iac/helm/README.md#observability-split-do-not-duplicate-ansible). Cases: [10](../../case-studies/10-ansible-estate.md), [11](../../case-studies/11-helm-estate.md).

## Host (Ansible)

| Layer | Path | Job |
|-------|------|-----|
| Prom → VictoriaMetrics | [`../../iac/ansible/reference/ansible-app-platform/`](../../iac/ansible/reference/ansible-app-platform/) `monitoring_deploy` | Scrape estate + Kubernetes SD + blackbox + cAdvisor. Compose with remote_write |
| Host Grafana + vmalert | [`../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/`](../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/) | Roles for VM + Grafana + Alertmanager + PAN-OS / EDR exporters. SOPS contract. Compose `stack/` is not published |
| Node scrape | [`../../iac/ansible/reference/ansible-estate/`](../../iac/ansible/reference/ansible-estate/) | `:9100` on the VM; cert-monitoring docker_app next to it |
| Before Prom | [`../../iac/ansible/reference/monitoring-starter/`](../../iac/ansible/reference/monitoring-starter/) | sysstat / vnstat timers |

Ansible scrapes. The Helm overlay **alerts on** those host metrics (`node-exporter-host.yaml`). It does not replace host Prom.

## In-cluster overlay (Helm, CCE envelope)

Living tree: [`../../iac/helm/reference/helm-estate-cluster/monitoring/`](../../iac/helm/reference/helm-estate-cluster/monitoring/).

| Piece | In git | Job |
|-------|--------|-----|
| `grafana/alerts/*.yaml` | copy | **12** provisioned groups, contact points, policies, templates |
| `grafana/dashboards/*.json` | copy | **14** artefacts. Sidecar is **off** |
| CloudEye + cloud-status exporters | copy | Managed Kafka / RDS / emergency work in the same Grafana |
| OpenObserve collector | copy | Custom DaemonSet. CCE hostPath `container_logs` |
| Grafana / Prom / OO vendor charts | document | Pins in the overlay README. Trees stay out |

## Addons (other estates)

Not bundled into the CCE overlay folder. Diagram 11 draws them as dotted edges.

| Piece | Path |
|-------|------|
| **12** CustomPrometheusRules | [`../../iac/helm/reference/helm-addons-extra/custom-prometheus-rules/`](../../iac/helm/reference/helm-addons-extra/custom-prometheus-rules/) |
| ElastAlert2 + Falco | [`../../iac/helm/reference/helm-addons-extra/elastalert2/`](../../iac/helm/reference/helm-addons-extra/elastalert2/) |
| ELK / ECK | [`../../iac/helm/reference/helm-addons-extra/elk/`](../../iac/helm/reference/helm-addons-extra/elk/) |
| OTel collector | [`../../iac/helm/reference/helm-addons-extra/opentelemetry-collector/`](../../iac/helm/reference/helm-addons-extra/opentelemetry-collector/) |
| Jaeger | [`../../iac/helm/reference/helm-data-plane/`](../../iac/helm/reference/helm-data-plane/) |

## Why the split exists

Cybersec and host on-call already had VictoriaMetrics and a VM Grafana. Copying that stack into the cluster would have been a second source of truth. The overlay adds **provisioned** Grafana on CCE, cloud exporters, and pod logs. Addons cover log-runtime and PromQL on estates that already ran Deckhouse or ELK. Hiring should parse three columns, not one "we have monitoring" box.
