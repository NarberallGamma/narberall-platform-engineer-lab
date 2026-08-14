# Case studies

NDA-safe narratives. Each links to diagrams and related code under `iac/` and `reference/`.

The same engineer owns **greenfield** platforms and **legacy** estates (import, runbooks, monitoring, incidents). About **six years**, senior in platform niches: bank/SBP-class, blockchain, delivery e-commerce, Atlassian/Nextcloud, 50+ microservices and JVM monoliths, **Jenkins** and **GitLab CI + Argo CD** — [`docs/experience.md`](../docs/experience.md). Delivery in a large team with a lead, as a de facto lead (train/delegate), and as the single owner on concurrent projects (reachable). Loaded production: high RPS, **~99.9% SLA**, seamless migrations, multi-zone HA. Kubernetes across OpenShift / Deckhouse / vanilla / cloud PaaS. DBMS under load (long SQL, locks, replication, sharding). Crisis work: off-hours restore, connectivity when a path is blocked, Cisco-style 7-step. Security from day one: hardening, EDR, Vault / ESO, SonarQube/Trivy/OSV; repos and pipelines laid out for developers, on-call, and audit.

Ansible / home-lab edge is **not** a client case study; it lives in [`practice/home-lab/edge-platform.md`](../practice/home-lab/edge-platform.md) and [`iac/ansible/`](../iac/ansible/).

| ID | Topic | Diagram |
|----|-------|---------|
| [`01-ai-llm-platform.md`](01-ai-llm-platform.md) | GPU / LLM inference platform | [`diagrams/case-studies/01-ai-llm-platform.md`](../diagrams/case-studies/01-ai-llm-platform.md) |
| [`02-cloud-platform-turnkey.md`](02-cloud-platform-turnkey.md) | Terraform from zero, multi-env turnkey | [`diagrams/case-studies/02-cloud-platform-turnkey.md`](../diagrams/case-studies/02-cloud-platform-turnkey.md) |
| [`03-document-ai-pipeline.md`](03-document-ai-pipeline.md) | OCR / document AI pipeline | [`diagrams/case-studies/03-document-ai-pipeline.md`](../diagrams/case-studies/03-document-ai-pipeline.md) |
| [`04-terraform-brownfield-import.md`](04-terraform-brownfield-import.md) | Import hand-built cloud into state | [`diagrams/case-studies/04-terraform-brownfield-import.md`](../diagrams/case-studies/04-terraform-brownfield-import.md) |
| [`05-legacy-estate-as-code.md`](05-legacy-estate-as-code.md) | **Proof of legacy:** 70+ console-built VMs, full network/SG catalog from zero, import, clean plan | [`diagrams/case-studies/05-legacy-estate-as-code.md`](../diagrams/case-studies/05-legacy-estate-as-code.md) |
| [`06-vmware-vcd-greenfield.md`](06-vmware-vcd-greenfield.md) | **VCD from zero:** catalog, guest init, DB-class VM, one-button CI stages | [`diagrams/case-studies/06-vmware-vcd-greenfield.md`](../diagrams/case-studies/06-vmware-vcd-greenfield.md) |

Use [`_template.md`](_template.md) for new entries.
