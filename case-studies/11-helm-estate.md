# Case study: Huawei-class estate Helm

**Context:** loaded Kubernetes on Huawei-class CCE; managed Kafka and RDS; Helm plus Argo CD  
**Timeline:** cluster envelope, mesh install, GitOps door, observability overlay  
**Role:** Platform Engineer (Helm and GitOps owner for the estate)

This is **proof** that the Huawei-class story is not only a compute catalog and a host runbook. [Case 07](07-huawei-compute-catalog.md) is the Terraform root (CCE, RDS, purpose ECS). [Case 10](10-ansible-estate.md) is what runs **on those hosts**. I used this envelope on CCE: brokers and Postgres in production were managed; Helm owned Connect, mesh egress, secrets bootstrap, the GitOps entry, load balancers, and the observability overlay. Alerts that on-call can act on do not require publishing 30 product charts.

Product umbrellas now exist as **samples** under [`iac/helm/apps/`](../iac/helm/apps/) (one richest copy per mechanic). That is not thirty shop charts on CCE.

## Challenge

The cluster is not a Friday YAML copy. Workloads must leave the mesh on purpose (sidecar to egress gateway to a VPS proxy), not through every pod. Outbox CDC must land on the **external** broker, not a second Kafka inside CCE. Vault stays outside; the cluster only gets a ClusterSecretStore and an operator. Argo needs a project and HA values without publishing Application lists or repo secrets. On-call needs Grafana alerts and an OpenObserve collector without vendoring Prometheus or copying 30 microservice umbrellas.

## Architecture

See diagram: [`diagrams/case-studies/11-helm-estate.md`](../diagrams/case-studies/11-helm-estate.md)

```text
1) istio: STRICT mTLS, PeerAuthentication, VPS egress CRs, egress-gateway values
2) kafka: custom KafkaConnect, outbox PostgresConnectors, ExternalSecret
3) monitoring: Grafana alerts and dashboards, two cloud exporters, OpenObserve collector
4) vault: thin ClusterSecretStore wrap, server off
5) external-secrets-operator: values wrapper
6) argocd: namespace, project, HA values (bootstrap only)
7) loadbalancer: three cloud ELB Services
8) ingress: ingress-nginx values (Service off, rate-limit and TLS in controller.config)
9) postgresql: DEMO Zalando CR; production data stays on RDS
```

Honest scope: this CCE envelope is Istio, not Linkerd. Product umbrellas are curated samples in [`iac/helm/apps/`](../iac/helm/apps/), not thirty shop charts on this CCE. Vendor Grafana, Prometheus, OpenObserve, Strimzi, and AKHQ trees are documented (pin plus values keys), not copied. Deckhouse PromRules and ElastAlert2 live in the addons kit, not in this overlay. Host scrape (Prom to VictoriaMetrics, blackbox) lives in [`ansible-app-platform`](../iac/ansible/reference/ansible-app-platform/). Host Grafana / vmalert and node-exporter stay in Ansible ([case 10](10-ansible-estate.md)).

## What shipped (CCE envelope)

- Custom Istio chart: PeerAuthentication and selective egress
- Kafka Connect templates aimed at the managed broker
- Thin Vault wrap plus ESO values (estate pin **0.9.11**; later install kit is **2.9.0**)
- Argo bootstrap (door only)
- Three cloud ELB Services and ingress-nginx values
- Zalando Postgres CR for DEMO; operator NOTES
- In-cluster monitoring overlay: **12** Grafana alert groups (ledger, databases, CCE, CloudEye Kafka/RDS, Connect, node, Cloud.ru status, contact points, templates, policies), **14** dashboard JSON artefacts (sidecar off), CloudEye + Cloud.ru exporters, OpenObserve collector (CCE `container_logs` hostPath)

## Also in the public Helm lab (other estates)

These kits are not the CCE envelope above. They are the rest of the published Helm library.

- Mesh install kit: Istio `base` plus `istiod` 1.30.3, ESO 2.9.0
- Data-plane kit: Linkerd, Jaeger, NiFi (shop-class estate that did not pick Istio)
- Extra addons: MinIO, OTel, ELK/ECK, **12** CustomPrometheusRules, ElastAlert2/Falco (**13** rules), SonarQube, Supabase, OpenVPN admin, werf backup, Dagster overlay
- KB examples: Deckhouse authz, Redis operator, Borg, restic
- Product samples: Keycloak overlay (codecentric 17.0.2, not Bitnami Keycloak), estate umbrellas, helmfile DEV stand, werf and OCI packaging. Hub: [`iac/helm/apps/`](../iac/helm/apps/)

## Results

- A cluster envelope change is a chart or values PR, not a console ritual
- Infra charts move through CI `helm upgrade`; product apps wait on the Argo door
- Reviewers parse custom CRs and Connect templates, not a tarball dump
- Host scrape and in-cluster overlay stay complementary
- On-call gets Grafana views and alert groups I can add or edit the same day (Grafana HTTP + git). CloudEye exporters close the managed-broker blind spot. Manager page: [`../architecture/05-sre.md`](../architecture/05-sre.md)

## Stack

Helm, Argo CD, Istio, Kafka Connect, Debezium, Strimzi (operator values), Vault, External Secrets Operator, ingress-nginx, Zalando Postgres, Grafana, Prometheus, VictoriaMetrics, CloudEye, OpenObserve, Huawei-class CCE, managed Kafka, managed RDS

Shop-class contrast (other kits): Linkerd, Jaeger, NiFi, ElastAlert2, OpenTelemetry, ELK/ECK

## Links

- Helm hub: [`iac/helm/`](../iac/helm/)
- Product samples: [`iac/helm/apps/`](../iac/helm/apps/)
- Overlay volume (alert keys + dashboard names): [`iac/helm/reference/helm-estate-cluster/monitoring/`](../iac/helm/reference/helm-estate-cluster/monitoring/)
- Estate cluster: [`iac/helm/reference/helm-estate-cluster/`](../iac/helm/reference/helm-estate-cluster/)
- Mesh and ESO install: [`iac/helm/reference/helm-mesh-eso/`](../iac/helm/reference/helm-mesh-eso/)
- Data plane: [`iac/helm/reference/helm-data-plane/`](../iac/helm/reference/helm-data-plane/)
- Addons: [`iac/helm/reference/helm-addons-extra/`](../iac/helm/reference/helm-addons-extra/)
- PromRules pack: [`iac/helm/reference/helm-addons-extra/custom-prometheus-rules/`](../iac/helm/reference/helm-addons-extra/custom-prometheus-rules/)
- ElastAlert2 + Falco: [`iac/helm/reference/helm-addons-extra/elastalert2/`](../iac/helm/reference/helm-addons-extra/elastalert2/)
- KB examples: [`iac/helm/reference/helm-kb-examples/`](../iac/helm/reference/helm-kb-examples/)
- Host observability (Ansible): [`iac/ansible/reference/ansible-app-platform/`](../iac/ansible/reference/ansible-app-platform/), [`iac/ansible/reference/ansible-llm-collab/extras/sec-stack/`](../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/), [`iac/ansible/reference/ansible-estate/`](../iac/ansible/reference/ansible-estate/), [`iac/ansible/reference/monitoring-starter/`](../iac/ansible/reference/monitoring-starter/)
- SRE / product APIs: [`../architecture/05-sre.md`](../architecture/05-sre.md)
- Terraform catalog: [`07-huawei-compute-catalog.md`](07-huawei-compute-catalog.md)
- Host Ansible: [`10-ansible-estate.md`](10-ansible-estate.md)
