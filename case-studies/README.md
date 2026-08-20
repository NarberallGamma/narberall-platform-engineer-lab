# Case studies

**Business first:** LLMOps (01, 03) is process speed. Cloud cases are days-to-weeks, audit, and a planned move. Manager hub: [`../architecture/`](../architecture/). Buyer page: [`../docs/for-business.md`](../docs/for-business.md). Existing case bodies stay; more cases can be added later.

NDA-safe narratives. Each links to diagrams and related code under `iac/` (Terraform, Ansible, and Helm kits) and `practice/` (home-lab kits and workstation MCP).

The same engineer owns **greenfield** platforms and **legacy** estates (import, runbooks, monitoring, incidents). About **six years**, senior in platform niches: bank/SBP-class, blockchain, delivery e-commerce, Atlassian/Nextcloud, 50+ microservices and JVM monoliths, **Jenkins** and **GitLab CI + Argo CD** — [`docs/experience.md`](../docs/experience.md). Delivery in a large team with a lead, as a de facto lead (train/delegate), and as the single owner on concurrent projects (reachable). Loaded production: high RPS, **~99.9% SLA**, seamless migrations, multi-zone HA. Kubernetes across OpenShift / Deckhouse / vanilla / cloud PaaS. DBMS under load (long SQL, locks, replication, sharding). Crisis work: off-hours restore, connectivity when a path is blocked, Cisco-style 7-step. Security from day one: hardening, EDR, Vault / ESO, SonarQube/Trivy/OSV; repos and pipelines laid out for developers, on-call, and audit.

Home-lab edge (Xray / VPS) is **not** a client case study; it lives in [`practice/home-lab/edge-platform.md`](../practice/home-lab/edge-platform.md). Payments identity autodeploy is case **08**. Huawei-class estate Ansible is case **10**. Huawei-class estate Helm is case **11**. Observability catalog: [`../docs/sre/`](../docs/sre/). Product APIs: [`../architecture/06-product-apis.md`](../architecture/06-product-apis.md).

| ID | Topic | Diagram |
|----|-------|---------|
| [`01-ai-llm-platform.md`](01-ai-llm-platform.md) | Private GPU API + collab estate (Nextcloud, n8n, Kafka, CIS) | [`diagrams/case-studies/01-ai-llm-platform.md`](../diagrams/case-studies/01-ai-llm-platform.md) |
| [`02-cloud-platform-turnkey.md`](02-cloud-platform-turnkey.md) | Terraform from zero, multi-env turnkey | [`diagrams/case-studies/02-cloud-platform-turnkey.md`](../diagrams/case-studies/02-cloud-platform-turnkey.md) |
| [`03-document-ai-pipeline.md`](03-document-ai-pipeline.md) | OCR / document AI pipeline | [`diagrams/case-studies/03-document-ai-pipeline.md`](../diagrams/case-studies/03-document-ai-pipeline.md) |
| [`04-terraform-brownfield-import.md`](04-terraform-brownfield-import.md) | Import hand-built cloud into state | [`diagrams/case-studies/04-terraform-brownfield-import.md`](../diagrams/case-studies/04-terraform-brownfield-import.md) |
| [`05-legacy-estate-as-code.md`](05-legacy-estate-as-code.md) | **Proof of legacy:** 70+ console-built VMs, full network/SG catalog from zero, import, clean plan | [`diagrams/case-studies/05-legacy-estate-as-code.md`](../diagrams/case-studies/05-legacy-estate-as-code.md) |
| [`06-vmware-vcd-greenfield.md`](06-vmware-vcd-greenfield.md) | **VCD from zero:** catalog, guest init, DB-class VM, one-button CI stages | [`diagrams/case-studies/06-vmware-vcd-greenfield.md`](../diagrams/case-studies/06-vmware-vcd-greenfield.md) |
| [`07-huawei-compute-catalog.md`](07-huawei-compute-catalog.md) | **Huawei compute catalog:** split state, CCE/RDS/purpose ECS, import then a new Teleport VM | [`diagrams/case-studies/07-huawei-compute-catalog.md`](../diagrams/case-studies/07-huawei-compute-catalog.md) |
| [`08-payments-swarm-autodeploy.md`](08-payments-swarm-autodeploy.md) | **SBP-class identity autodeploy:** Swarm first, same roles for Kubernetes | [`diagrams/case-studies/08-payments-swarm-autodeploy.md`](../diagrams/case-studies/08-payments-swarm-autodeploy.md) |
| [`09-selectel-vpc-and-dedicated.md`](09-selectel-vpc-and-dedicated.md) | **Selectel:** OpenStack VPC + dedicated Proxmox on the same RU cloud/DC | [`diagrams/case-studies/09-selectel-vpc-and-dedicated.md`](../diagrams/case-studies/09-selectel-vpc-and-dedicated.md) |
| [`10-ansible-estate.md`](10-ansible-estate.md) | **Huawei-class estate Ansible:** docker_app, Vault, hibernate, DB users | [`diagrams/case-studies/10-ansible-estate.md`](../diagrams/case-studies/10-ansible-estate.md) |
| [`11-helm-estate.md`](11-helm-estate.md) | **Huawei-class estate Helm:** Istio egress, Kafka Connect, Vault/ESO, Argo door, Grafana overlay (same-day views) | [`diagrams/case-studies/11-helm-estate.md`](../diagrams/case-studies/11-helm-estate.md) |

Use [`_template.md`](_template.md) for new entries.
