# Cloud Foundation

**Duration:** depends on footprint (typical multi-day to multi-week)

**Business:** IAM, network, CI, and monitoring in **days to a couple of weeks**. Night park for idle non-prod is in scope when the estate is cloud.ru / Huawei-class or AWS-shaped. [`../architecture/00-days-not-months.md`](../architecture/00-days-not-months.md).

## Deliverables

- IaC baseline (network, IAM, compute patterns) — greenfield apply or brownfield import
- CI/CD and environment promotion path: **Jenkins** and/or **GitLab CI + Argo CD** (branch/tag, GitOps)
- Observability starter
- Documentation for handoff
- Kubernetes and DBMS as operated platforms (not only provisioned): load, replication, sharding, balancers
- Messaging on the path: Kafka / RabbitMQ / NATS / Artemis / Redis as the estate uses them
- Application CI: build → **SonarQube / Trivy / OSV-Scanner** → promote
- Production bar: multi-zone HA, seamless migrations, observability aimed at ~99.9% SLA
- Security from the first apply: OS/IAM hardening, EDR where the estate uses it, users and rights, **Vault** / cloud secrets / **ESO** (introduce if missing)
- Git and pipelines: separate repos (not a dump monorepo), branches that match promotion, layout that audit and a new engineer can walk

## Proof in this repo

- Case study: `case-studies/02-cloud-platform-turnkey.md`
- VCD + one-button host CI: `case-studies/06-vmware-vcd-greenfield.md`, `iac/ci/`
- Huawei compute catalog (split state): `case-studies/07-huawei-compute-catalog.md`, `iac/terraform/cloud-ru-compute/`
- Code: `iac/terraform/`, [`../iac/ansible/`](../iac/ansible/) (`monitoring-starter`, estate / app-platform kits), [`../iac/helm/`](../iac/helm/) (cluster kits + [`apps/`](../iac/helm/apps/) samples)
- Cases 10–11: host Ansible + Helm estate overlay on the same Huawei-class story
