# Positioning

**Business filter:** whatever the infra needs, **fast**, written down, **minimal windows**, **~99.9% SLA**. Lower idle bill (night park on non-prod). OCR/LLM that shortens real document work. Cloud move is one fast skill, not the headline. Buyer page: [`for-business.md`](for-business.md). Manager diagrams: [`../architecture/`](../architecture/). Existing cloud notes and case bodies stay as they are.

## Role

**Platform Engineer · AI & Cloud Infrastructure**  
About **six years** on the market. Strong senior in platform / loaded production / CI/CD niches. Turnkey delivery: infrastructure, application delivery (build → gates → prod), documentation, monitoring, and incident operations.

Full six-year narrative (domains, JVM, brokers, org): [`experience.md`](experience.md).

## Scope of ownership

**Greenfield:** empty cloud project or bare metal through IAM, VPC, Kubernetes, CI/CD, apps, and observability. New VMs follow a **one-button** path (Terraform / guest init → Ansible → Vault → monitoring → docs); detail: [`../iac/ci/`](../iac/ci/).

**Legacy:** arrive on a hand-built estate, automate it, document it, add monitoring, cut waste, and keep shipping without a reckless rewrite. **Proof in this lab:** [`../case-studies/05-legacy-estate-as-code.md`](../case-studies/05-legacy-estate-as-code.md) (70+ console-built VMs, full network/SG catalog from zero, import, clean plan).

**Loaded production:** high RPS and large user bases with an annual **~99.9% SLA**. Seamless migrations, multi-zone HA, fault tolerance, metrics that catch a breach early.

**Crisis:** complex incidents including off-hours. Restore a downed production service (logs + metrics, isolate the layer). Restore connectivity when routing or path blocks cut reachability. Method: **Cisco-style seven-step** (1 define the problem, 2 gather facts, 3 analyze, 4 eliminate causes, 5 hypothesize, 6 test, 7 solve and document).

**Security (day one, no separate TZ required):** industry best practices on hosts and IAM, **EDR** on the estate, OS hardening, users and rights. Secrets: **Vault** and/or cloud stores plus Kubernetes **External Secrets Operator (ESO)** — introduce from scratch if missing; never long-lived secrets in git. CI gates from zero: **SonarQube**, **Trivy**, **OSV-Scanner**.

**How the code is organized:** not a dump monorepo. App, IaC, and pipelines in repos and branches that match promotion. Layout obvious enough that developers, on-call, and **business / technical audit** can walk IAM, secrets, and change history without a reconstruction project. Security that stays operable — not a gate that makes every deploy painful.

**Hardware and OS depth** (home lab and small-office metal): PCs and simple office servers assembled by hand; BIOS/UEFI; RAM/CPU/GPU **overclock and undervolt** with HWiNFO-class sensors (turnkey PC, not “it POSTed”). Diagnosis at hardware **and** OS. Linux kernel (modules, sysctl, traces) and Windows registry/services when the fault lives there. Same machine tuned for LLM, Stable Diffusion, games, and vendor software. Breadth is not limited to cloud consoles and a terminal on a VM. Detail: [`practice/home-lab/os-workstation.md`](../practice/home-lab/os-workstation.md).

**Workstation / local AI (same calendar as the cloud offer, not a hobby):** MCP and scripts so Terraform, Ansible, JSM, Grafana, Vault, Argo, and GPU jobs run from the IDE with tokens on disk. I already run that as a **multi-agent desk**: Cursor, Claude Code, Codex, and a local Ollama / llama.cpp loop, plus the usual VS Code-class wrappers (Continue, Cline, Roo, Copilot Chat, Aider). Replicate-class HTTP when VRAM does not fit. That is how a current engineer works when the business asks for days, not weeks. It sits on **about four years** of the same work done **by hand** (charts, Ansible, CI, bash, deploys) before coding agents existed. Much of the published lab is from that period. I still ship without agents when the estate forbids them; the calendar is just longer, because one person is not ten parallel workers. The same habit covers **almost every product API** on the estate (monitoring first). Tenant data stays off a public chat. Bootstrap is bash + Docker + `mcp.json` — **Linux, macOS, or WSL**; Windows was one host, not the product. Detail: [`../practice/workstation/mcp-ops-toolchain.md`](../practice/workstation/mcp-ops-toolchain.md), [`../architecture/06-product-apis.md`](../architecture/06-product-apis.md), [`security-ai.md`](security-ai.md).

**How I work:** I have shipped in a **large team with a dedicated lead** — that is a normal and welcome mode. On later engagements I **trained people and delegated** as a de facto lead (badge optional) while reporting **directly** to PMs, CTOs / technical directors, team leads, and **tech leads of the whole project**. I also own a whole platform as the **single engineer**, often across **more than one project at once**, and stay reachable on those threads. Solo delivery means full ownership and responsiveness, not a preference against teams.

**Domains (six years, NDA-safe):** large **bank / SBP-class** payments (RF Faster Payments, B2B/P2P, Swarm then Kubernetes, mTLS); **treasury / trade-finance / documents** (Helm, Argo CD, Vault/ESO, Kafka/Debezium); **blockchain / smart-contract** programmes; **delivery e-commerce** (food, grocery, thousands of users per hour, 50+ Spring, Superset, NiFi); **Atlassian**, **Nextcloud**, **1C**; enterprise **ITSM / EDO / CRM**; multi-tenant **Deckhouse** estates; LLM/OCR / enterprise capture. Runtime path: Java, Kotlin, C#/.NET, Go, Python (Django/FastAPI), PHP (Laravel), Node.js, 1C:Enterprise. CI: **Jenkins** (plugins, workers, dedicated VMs → Kubernetes), **GitLab CI + Argo CD**, **Azure DevOps**, **Helm + werf**. Gates from zero: **SonarQube**, **Trivy**, **OSV-Scanner**. Glue: Kafka, Debezium, RabbitMQ, NATS, Artemis, Redis. Data: PG/Patroni, MySQL, MSSQL, Oracle, Mongo, ClickHouse. Platforms: Superset, Supabase, Airflow, n8n, NiFi, Harbor, MinIO, Ceph, Keycloak, Teleport. Observability/SRE: Prometheus, Alertmanager, Grafana, VictoriaMetrics, OpenObserve, Loki, ELK/Logstash, Graylog, Jaeger, OpenTelemetry, CloudEye (product APIs, same-day views). Estates: **50+ microservices** and heavy **JVM/Tomcat monoliths** (heap dumps, thread dumps, GC). Tables: [root README](../README.md#six-years-domains-apps-brokers-jvm). Detail: [`experience.md`](experience.md).

## Kubernetes and data

- Clusters: **OpenShift**, **Deckhouse**, vanilla Kubernetes, and cloud PaaS (EKS / CCE / GKE-class)
- Databases under load: long SQL, locks/blocking, replication lag and failover, read/write spread, balancers in front of the data path, **sharding** when one primary is the ceiling. PostgreSQL users as code (Flyway/DDL vs app DML, extra RO/RW): [`../iac/ansible/reference/ansible-estate/`](../iac/ansible/reference/ansible-estate/). Same ops pattern in private estates.
- Messaging and cache on the critical path: **Kafka**, **Debezium**, **RabbitMQ**, **NATS**, **Artemis**, **Redis**
- Application delivery: Java/Kotlin JVM (including Tomcat and dumps), .NET, Go, Python, PHP, Node, 1C — plus CI gates (SonarQube, Trivy, OSV-Scanner)
- CI/CD: **Jenkins** (plugins, Kubernetes workers instead of dedicated VMs), **GitLab CI + Argo CD**, **Azure DevOps**, **Helm + werf**. Cluster envelope: [`../iac/helm/`](../iac/helm/), product samples: [`../iac/helm/apps/`](../iac/helm/apps/), [case 11](../case-studies/11-helm-estate.md). Images and Compose: [`../iac/docker/`](../iac/docker/), [case 12](../case-studies/12-docker-images.md). Living CI kits (create → accompany → build/publish → gates → revoke): [`../iac/ci/`](../iac/ci/), [case 13](../case-studies/13-ci-pipelines.md)
- Observability / SRE: Prometheus + Alertmanager + Grafana, **VictoriaMetrics**, **OpenObserve** + OTel Collector, Loki, ELK/Logstash, Graylog, Jaeger, CloudEye exporters. I use those **product APIs** to add and edit views the same day. Complementary layers in this lab (host Ansible + in-cluster Helm + addons). Map: [`sre/`](sre/), [`../architecture/05-sre.md`](../architecture/05-sre.md), [case 10](../case-studies/10-ansible-estate.md), [case 11](../case-studies/11-helm-estate.md).
- Estate APIs (same habit, not only monitoring): **Vault** HTTP, **Argo CD** sync/wait, Kubernetes logs/SD, **JSM / Confluence** REST, **GitLab** pipelines, **n8n** workflow GitOps, Harbor / MinIO / SonarQube, cloud providers, **Replicate** async create + poll. Scripts first, then IDE agents. Tokens in `chmod 600` env files.

## Cloud and compute

See [`iac/cloud/`](../iac/cloud/) for per-platform write-ups and links into Terraform.

- **cloud.ru / Huawei Cloud** (AWS-shaped resource model; strong transferable AWS practice). Second estate: [compute catalog](../iac/terraform/cloud-ru-compute/) (CCE, RDS, purpose ECS, split state)
- **VK Cloud / NOVA Cloud class** (Kazakhstan; OpenStack under the hood: Nova, Cinder, Neutron, Keystone; provider `vkcs`)
- **VMware Cloud Director** (cloud.ru VMware / VCD; provider `vmware/vcd`; guest init + CI hooks)
- **AWS**, **Google Cloud**, **Yandex Cloud**, **DigitalOcean**, **Hetzner**
- **Selectel** (top-tier RU cloud/DC: OpenStack VPC **and** dedicated Proxmox)
- **OpenStack / Selectel Cloud**, **Proxmox**, **bare metal**
- **Cloudflare** (DNS as code)

**Education:** B.Sc. in Information Systems and Technologies (09.03.02), The Bonch-Bruevich Saint Petersburg State University of Telecommunications (SPbSUT). Cisco, campus networks and servers in the curriculum; Windows Server practice at IT companies during studies. Detail: [`experience.md#education`](experience.md#education).

## Audience

- Hiring managers / tech leads (employment or contract) — team seat or the single platform owner
- Founders needing MVP + AI + deploy
- Teams with legacy infra that must become operable fast
- Agencies needing white-label infra / backend

## Offers (see `/packages`)

1. **AI Infra Sprint** - LLM/RAG stack, monitoring, backups
2. **Cloud Foundation** - IaC, IAM, networking, CI/CD (greenfield or import)
3. **Full Turnkey** - app + infra + AI + docs + observability

## Proof model

Case studies (outcomes) + [`experience.md`](experience.md) (six years) + [`iac/cloud/`](../iac/cloud/) (keywords) + [`iac/terraform/`](../iac/terraform/) (code) + [`iac/ansible/`](../iac/ansible/) (hosts) + [`iac/helm/`](../iac/helm/) (cluster) + [`iac/helm/apps/`](../iac/helm/apps/) (product samples) + [`iac/docker/`](../iac/docker/) (images and Compose) + [`iac/ci/`](../iac/ci/) (living pipeline kits) + [case 10](../case-studies/10-ansible-estate.md) + [case 11](../case-studies/11-helm-estate.md) + [case 12](../case-studies/12-docker-images.md) + [case 13](../case-studies/13-ci-pipelines.md) + live portfolio site.  
Not a dump of private client IaC.
