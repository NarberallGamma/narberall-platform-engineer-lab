# Estate cluster (Helm)

**Business first:** the production cluster has a **door** (Argo), a **mesh policy**, CDC on the managed broker, and alerts that fire on SLI. Buyer page: [`../../../../docs/for-business.md`](../../../../docs/for-business.md). Case: [`../../../../case-studies/11-helm-estate.md`](../../../../case-studies/11-helm-estate.md).

I used this envelope on a Huawei-class CCE estate (AWS-shaped). Brokers and Postgres in production were **managed** (DMS / RDS). What Helm owned was Connect, mesh egress, secrets bootstrap, GitOps entry, load balancers, and the observability overlay.

Brand, live FQDNs, Vault paths, and registry hosts are stripped. Custom templates stay so a reviewer can parse the CRs, not a vendor tarball.

Hub: [`../`](../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Host observability stays in Ansible (do not duplicate here): [`../../../ansible/`](../../../ansible/).

```text
helm-estate-cluster/
  istio/                      # PeerAuthentication + VPS egress CRs; egress-gateway values excerpt
  kafka/                      # custom Connect + connector templates + values excerpt
  monitoring/                 # alerts, dashboards, two cloud exporters, OpenObserve collector
  vault/                      # thin ClusterSecretStore wrap (server off)
  external-secrets-operator/  # values wrapper
  argocd/                     # bootstrap only (values, namespace, project)
  loadbalancer/               # three cloud ELB Services
  ingress/                    # values.example.yaml (upstream ingress-nginx)
  postgresql/                 # DEMO Zalando CR + operator NOTES
```

## Who this page is for

Hiring lead: this is the cluster I actually ran, reduced to the unique templates. Engineer: each folder README says copy vs NOTES.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Istio custom chart | STRICT mTLS on app workloads. Selective egress: mesh → egress gateway → VPS proxy. Telegram alerts on; chain RPC routes off in prod |
| Kafka custom templates | One KafkaConnect, outbox PostgresConnectors, ExternalSecret, Strimzi 0.46 workarounds. Broker is outside the cluster |
| Monitoring overlay | **12** Grafana alert files + **14** dashboard JSON artefacts, two cloud exporters, OpenObserve collector. Grafana/Prometheus/OpenObserve vendor trees are documented only |
| Vault thin wrap | External Vault. Helm only bootstraps ClusterSecretStore + SA |
| Argo bootstrap | Namespace, project, HA values. Applications and repo secrets stay out |
| 3-ELB + ingress values | Cloud load balancers owned by a thin chart. ingress-nginx Service disabled; rate-limit and TLS in `controller.config` |
| Zalando PG | In-cluster operator path for a lab/DEMO. Production data is RDS |

## Observability split

See the hub table: [`../../README.md#observability-split-do-not-duplicate-ansible`](../../README.md#observability-split-do-not-duplicate-ansible).

In this kit: OpenObserve collector + Grafana provisioning + cloud exporters. Host VictoriaMetrics / Grafana / node-exporter stay under `iac/ansible/`. I add and edit Grafana views through git and the Grafana HTTP API the same day. Manager page: [`../../../../architecture/05-sre.md`](../../../../architecture/05-sre.md). Catalog: [`../../../../docs/sre/`](../../../../docs/sre/).

## Vendor charts (documented, not vendored)

| Chart | Pin (as used) | What I changed | In git |
|-------|---------------|----------------|--------|
| Strimzi | 0.46.0, `watchAnyNamespace` | Operator values only | NOTES |
| AKHQ | 0.3.1 | `existingSecrets` + parent secret override | NOTES |
| ingress-nginx | 1.13.3 | HA 3, `controller.config` rate-limit 1000/1m, Service off | `ingress/values.example.yaml` |
| Grafana | helm 10.4.0 / app 12.3.0 | `alerting:` map, SMTP via ESO, Istio inject, sidecar off, Recreate+PVC | alerts + dashboards + one template |
| Prometheus | 27.50.1 | scrape topology, 350Gi, kube-state/node subcharts off | NOTES |
| OpenObserve | 0.70.1 | HA 2× router/ingester/querier, object store + RDS, 60d | collector chart + README |
| HashiCorp Vault | 0.28.1 metadata | server/injector/csi/ui off; ESO on | thin templates |

## Product samples

Not in this kit. Curated samples live under [`../../apps/`](../../apps/) (Keycloak overlay, estate umbrellas, helmfile, werf, OCI). One richest copy per mechanic, not thirty-seven services. Blockchain in the portfolio is Istio egress + ExternalSecret keys, not three node charts.

## Sanitize

[`../../SANITIZE.md`](../../SANITIZE.md). No Argo repo secrets, no connector passwords, no live broker FQDNs.

**Keywords:** Istio, PeerAuthentication, egress gateway, Kafka Connect, Debezium, outbox, External Secrets, Vault, Argo CD, ingress-nginx, OpenObserve, Grafana, Zalando Postgres, cloud ELB
