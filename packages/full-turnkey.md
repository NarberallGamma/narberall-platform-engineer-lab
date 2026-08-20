# Full Turnkey

**Duration:** scoped per MVP

**Business:** one owner who stands up, accompanies, and can migrate. Days-to-weeks for the baseline, then the product path. [`../docs/for-business.md`](../docs/for-business.md).

## Deliverables

- Application or site + utilities as needed
- Infrastructure and deploy path
- AI integration when required
- Docs + monitoring so the system is operable after handoff. New Grafana views and alert rules the same day (product APIs, not a vendor workshop): [`../architecture/05-sre.md`](../architecture/05-sre.md), [`../docs/sre/`](../docs/sre/)

## Message

One owner from infra to documentation and observability, including application **build, deploy, and gates** (Java, Kotlin, .NET, Go, Python, 1C; SonarQube / Trivy / OSV-Scanner). CI: **Jenkins** (plugins, workers, VM→Kubernetes) and **GitLab CI + Argo CD** (branch/tag, auto MR, merge rules). That can be **solo** on one or several concurrent products (reachable) — or as a teammate in a large org with a lead — or as a **de facto lead** who trains and delegates while reporting to a PM or CTO. About **six years** of that: bank/SBP-class, blockchain, delivery e-commerce, Atlassian/Nextcloud, 50+ services and JVM monoliths. Greenfield or **legacy**. Loaded production (~99.9% SLA): seamless migrations, multi-zone HA, DBMS and brokers under load, incidents including off-hours. **Secure by default**. Full narrative: `docs/experience.md`.

## Proof in this repo

- Case studies `01`–`03`, `10`–`11` (estate Ansible + Helm overlay)
- `practice/home-lab/reference/apps/`, `iac/ansible/reference/`, `iac/terraform/`, `iac/helm/reference/`, [`iac/helm/apps/`](../iac/helm/apps/), `practice/home-lab/reference/ai/`, `practice/workstation/reference/`
