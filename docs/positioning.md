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

**How I work:** I have shipped in a **large team with a dedicated lead** — that is a normal and welcome mode. On later engagements I **trained people and delegated** as a de facto lead (badge optional) while reporting **directly** to PMs, CTOs / technical directors, team leads, and **tech leads of the whole project**. I also own a whole platform as the **single engineer**, often across **more than one project at once**, and stay reachable on those threads. Solo delivery means full ownership and responsiveness, not a preference against teams.

**Domains (six years, NDA-safe):** large **bank / SBP-class** payments (RF Faster Payments, B2B/P2P, Swarm then Kubernetes, mTLS); **treasury / trade-finance / documents** (Helm, Argo CD, Vault/ESO, Kafka/Debezium); **blockchain / smart-contract** programmes; **delivery e-commerce** (food, grocery, thousands of users per hour, 50+ Spring, Superset, NiFi); **Atlassian**, **Nextcloud**, **1C**; enterprise **ITSM / EDO / CRM**; multi-tenant **Deckhouse** estates; LLM/OCR / enterprise capture. Runtime path: Java, Kotlin, C#/.NET, Go, Python (Django/FastAPI), PHP (Laravel), Node.js, 1C:Enterprise. CI: **Jenkins** (plugins, workers, dedicated VMs → Kubernetes), **GitLab CI + Argo CD**, **Azure DevOps**, **Helm + werf**. Gates from zero: **SonarQube**, **Trivy**, **OSV-Scanner**. Glue: Kafka, Debezium, RabbitMQ, NATS, Artemis, Redis. Data: PG/Patroni, MySQL, MSSQL, Oracle, Mongo, ClickHouse. Platforms: Superset, Supabase, Airflow, n8n, NiFi, Harbor, MinIO, Ceph, Keycloak, Teleport. Estates: **50+ microservices** and heavy **JVM/Tomcat monoliths** (heap dumps, thread dumps, GC). Tables: [root README](../README.md#six-years-domains-apps-brokers-jvm). Detail: [`experience.md`](experience.md).

## Kubernetes and data

- Clusters: **OpenShift**, **Deckhouse**, vanilla Kubernetes, and cloud PaaS (EKS / CCE / GKE-class)
- Databases under load: long SQL, locks/blocking, replication lag and failover, read/write spread, balancers in front of the data path, **sharding** when one primary is the ceiling. PostgreSQL / RDS-class in public code; same ops pattern in private estates.
- Messaging and cache on the critical path: **Kafka**, **Debezium**, **RabbitMQ**, **NATS**, **Artemis**, **Redis**
- Application delivery: Java/Kotlin JVM (including Tomcat and dumps), .NET, Go, Python, PHP, Node, 1C — plus CI gates (SonarQube, Trivy, OSV-Scanner)
- CI/CD: **Jenkins** (plugins, Kubernetes workers instead of dedicated VMs), **GitLab CI + Argo CD**, **Azure DevOps**, **Helm + werf**. Full map (create → accompany → build/publish → gates → revoke): [`../iac/ci/`](../iac/ci/)

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

Case studies (outcomes) + [`experience.md`](experience.md) (six years) + [`iac/cloud/`](../iac/cloud/) (keywords) + [`iac/terraform/`](../iac/terraform/) (code) + [`iac/ansible/`](../iac/ansible/) (day-2) + live portfolio site.  
Not a dump of private client IaC.
