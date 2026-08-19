# Six years in production

NDA-safe narrative. Client names stay out. Scale and sector stay in. This is the same six years as the cloud and Kubernetes pages — the part hiring usually cannot infer from Terraform alone.

**Same years, buyer language:** whatever the infra needs, in **days to a couple of weeks**, **documented**, **minimal windows**, **~99.9% SLA**. Audit then import. Park idle non-prod. OCR/LLM as a **multiplier** for accounting / analysts / developers. Cloud move is one of the things I do quickly when asked. Outcomes: [`for-business.md`](for-business.md). Diagrams: [`../architecture/`](../architecture/). Full domain and stack tables: [root README](../README.md#six-years-domains-apps-brokers-jvm).

**Role on the market:** about **six years** (through 2026). Positioned as a **strong senior in my niches**: platform / cloud / loaded production, CI/CD, day-2 of serious applications — not a generalist who “also clicked AWS once.” AI/LLM delivery is an additional niche on the same ownership pattern.

Client trees and bank internals are not in this public lab. What follows is the shape of the work.

---

## How I sat in the organisation

Official title was not always “Lead.” On later engagements I still **trained people, split the work, and owned the outcome** — de facto lead of the platform slice: onboarding, review, who does the night change, what “done” means for infra.

Reporting was **direct**, not buried under three layers of “infra tickets”:

| I reported to | What that meant in practice |
|---------------|-----------------------------|
| Project managers | Dates, blast radius, “can we ship Friday,” maintenance windows vs business calendar |
| Technical directors / CTOs | Risk, cost, architecture bets, what must not break SLA |
| Tech leads of a team | Shared backlog, reviews, who owns which service |
| Tech leads of the **whole project** | Cross-team contracts: payments vs shop vs identity vs platform |

I have also sat **in a large engineering organisation with a dedicated lead** — that mode is normal and welcome. The other mode (one platform owner, sometimes several products at once, reachable) is documented in the [root README](../README.md#how-i-work-team-solo-and-de-facto-lead). Both are real. Neither is a story about missing management.

---

## Domains (what “production” actually was)

The product changed. The bar did not: money, orders, or settlement in flight; a bad deploy is a business incident.

### Bank-grade payments (RF) — B2B / P2P, SBP-class

Accompanied **large bank and payments programmes**, including infrastructure next to **SBP** (Sistema Bystrykh Platezhei — Russia’s Faster Payments System: instant account-to-account, bank-grade). The public story is sector and class, not a claim to have designed the national switch.

What that class of work actually demands:

- Change windows that respect settlement and cut-off, not “we’ll bounce it at lunch”
- HA and failover that a bank risk committee can understand (zones, no single broker, no single DB as the only truth)
- Audit, secrets, who can apply prod — see [positioning](positioning.md) on Vault / ESO and gates
- Integrations that fail loudly (idempotency, retries, poison messages) because a silent drop is a reconciliation nightmare
- On-call that treats a stuck queue or a lock on the money path as **P1**, not a dashboard curiosity

B2B and P2P platforms in this era were the same idea: counterparties, ledgers, and SLAs, not a brochure site.

Identity in front of that class of estate is also coded: Access Manager + Identity Gateway (YARP) + Redis + Postgres as Ansible, Docker Swarm first, same roles later for Kubernetes. Public tree: [`../reference/ansible-payments-idplat/`](../reference/ansible-payments-idplat/), [case 08](../case-studies/08-payments-swarm-autodeploy.md).

### Blockchain and smart-contract programmes

Accompanied **large blockchain / smart-contract** products: nodes, keys, environments, deploy path, the unglamorous part that keeps a chain-facing app alive. Contract-level write-ups stay NDA-safe and will be expanded in case studies without vendor theatre. The platform job is the same: environments that cannot drift, secrets that cannot leak, releases that cannot “try again on mainnet.”

### Consumer delivery and e-commerce

Operated **large internet shops and delivery products** — food delivery, grocery, and similar — with **thousands of users per hour** at busy periods (lunch/evening spikes). That is enough traffic that:

- A dead checkout, cart, or courier assignment is immediately visible to the business
- Brokers, Redis, and the DB are on the critical path, not “nice to have cache”
- Rolling deploys and drain matter; a stop-the-world restart at peak is a self-inflicted outage

Same estate class as other **enterprise applications**: not a startup toy stack, not a Fortune-1 global marketplace claim. Honest scale, real incidents.

### Collaboration and internal platforms

Day-2 of **Atlassian** (Jira / JSM / Confluence / Bitbucket-class: install, SSO-adjacent, backup, upgrade, “why is it swapping”) and **Nextcloud** (files, sharing, identity, storage growth, OnlyOffice / Mattermost next to it). **1C:Enterprise** (Windows app farm + PostgreSQL), **Teleport**, nginx/WAF, **AD / ADFS**, GitLab, **n8n**. These are the systems everyone notices when they are down and nobody budgets as “real production” until they are.

### Treasury / trade-finance / document platforms

Loaded **Kubernetes** (prod + preprod): **Helm + Argo CD**, **Vault / ESO**, **Kafka + Debezium**, Camunda-class process engines, signing / HSM-adjacent VMs, Istio-class mesh. The bar is the same as payments: **minimal windows**, money and documents in flight.

### Document AI and enterprise capture

OCR and capture (ContentCapture-class) to structured JSON, then LLM extract, handoff to **1C** / ERP. Private GPU API so finance data does not go into a public chat. Cases 01 and 03 in the lab.

### Enterprise ITSM / EDO / CRM

High-load web: document exchange, counterparty monitoring, ITSM, CRM. **ELK / Graylog**, Grafana, Zabbix, Jira Service Desk, Tomcat, SQL from the incident, customer-facing SLA. Same Cisco-style loop.

### Enterprise Java product delivery

Vendor ITSM/BPM-class Java on **Tomcat**, Nginx/IIS, **Patroni + etcd**, Oracle / MSSQL / PostgreSQL / InfluxDB, **Artemis + Kafka**, **Keycloak** (SAML / OIDC / Kerberos / AD). Jenkins, Maven, Nexus / Artifactory. Train client engineers. Heap/thread dumps as in the monolith section.

### Multi-tenant Kubernetes estates

Many client platforms in parallel: **Deckhouse**, vanilla, OpenShift, cloud PaaS. **Helm + werf**, GitLab CI per environment. Compute from **bare metal / Proxmox** to AWS, Selectel, **Yandex Cloud**, **DigitalOcean**, Hetzner. **Supabase**, **Airflow**, **n8n**, **ClickHouse**, MongoDB, MySQL, **Harbor**, Ceph / MinIO in the same day-2 habit. Strict incident SLA: hot-fix and rollback the same day.

---

## Application delivery (build, deploy, gates)

I am not claiming to be the author of every business repo. I **owned the path from commit to production** for stacks that actually run in banks, shops, and internal platforms:

| Runtime | What I did with it |
|---------|---------------------|
| **Java** / **Kotlin** / **Spring Boot** | Build, image, Helm, deploy; JVM and servlet container under load (below) |
| **C# / .NET** | Build, publish, Windows or Linux, IIS/Kestrel, Swarm or Kubernetes |
| **Go** | Small static binaries, the easy deploy — still needs the same secrets, probes, and rollouts |
| **Python** (Django, FastAPI) | Services, jobs, AI-adjacent APIs; venv/image, not “works on my laptop” |
| **PHP (Laravel)** | Pack and ship prod-ready into the cluster (Helm/werf-class) |
| **Node.js** | Same GitOps path as the rest of the estate |
| **1C:Enterprise** | RU business stack: environments, publish, PG next to Windows 1C — not a claim to be a 1C functional consultant |

**CI security gates** I have stood up **from zero** (install, wire into the pipeline, make the gate mean something):

| Tool | Role in the path |
|------|------------------|
| **SonarQube** | Quality gate: smells, coverage where the team agreed, block merge on the rules that matter |
| **Trivy** | Image / filesystem / config: CVEs and misconfig before the artefact is promoted |
| **OSV-Scanner** | Dependency advisory (lockfiles) so the app does not ship a known-bad library because nobody looked |

Gates that fail closed on noise get bypassed. The job is a gate developers can live with and auditors can point at.

### Jenkins (deep) and GitLab CI + Argo CD (deeper)

The path above ran on real CI, not a screenshot of a green tick.

**Jenkins** — a lot of production time: controller, **plugins**, and **workers**. Classic pain is a farm of **dedicated build VMs** that rot (disk, JDK drift, “who installed that plugin”). I **moved that configuration onto Kubernetes**: workers as pods (scale with the queue, image in the registry, less snowflake metal), so builds got **faster** and day-2 got cheaper (no more babysitting a pile of worker boxes). Plugins stay in the picture (pipeline, Kubernetes executors, credentials, the usual estate) — the point is an operable Jenkins, not a museum of click-installed boxes.

**GitLab CI and Argo CD** — even more of the last years. That pair is how I prefer to ship when the estate allows it:

| Piece | What I actually set up |
|-------|-------------------------|
| GitLab CI | Build, test, gates (Sonar / Trivy / OSV), images, the promotion job — YAML in the repo, not a Jenkins UI as source of truth |
| Argo CD | GitOps into the cluster: desired state in git, sync that on-call can see, drift that is a ticket not a surprise |
| Branches and tags | **Seamless** deploys: branch → preview/dev/stage; **tag** → a named release toward prod — no “copy this YAML on Friday” |
| Merge requests | **Automatic MRs** when the pipeline says the artefact is ready (release branch, version bump, env promote) |
| Merge policy | Auto-merge when **parameters** match: green pipeline, required approvals, labels, “only this target branch” — the rules are written down, not tribal |

Seamless here is the same idea as the SLA section: the user (or the next service in the graph) should not see a maintenance window because someone clicked Deploy. Argo syncs a revision; GitLab already proved the revision. Rollback is another revision, not a SSH session.

---

## Messaging, cache, and the glue

Loaded systems are rarely “the app and Postgres.” The path I kept alive includes:

| Piece | Why it was on my plate |
|-------|-------------------------|
| **Apache Kafka** | High-volume events, consumer lag, partitions, retention, “why is prod 400 partitions behind” |
| **Debezium** | CDC off PostgreSQL / the money path into Kafka |
| **RabbitMQ** | Classic work queues, DLQ, split-brain and disk alarms |
| **NATS** | Lighter bus; still needs HA and “who is subscribed” |
| **Apache ActiveMQ Artemis** | Enterprise JMS-class broker next to Java estates |
| **Redis** | Cache, sessions, locks, rate limits — treat eviction and persistence as product decisions |
| **PostgreSQL** (incl. **Patroni + etcd**), MySQL, **MSSQL**, **Oracle**, MongoDB, **ClickHouse**, InfluxDB | Provision, backup, tune, long SQL, locks, replication |
| **Apache Superset**, **Supabase**, **Airflow**, **n8n**, **NiFi**, Camunda-class | BI, BaaS, jobs, automation, process/document flow |
| S3 / OBS, **MinIO**, **Ceph**, **Harbor** | Object data, cluster stores, the image path CI promotes |

A broker that is “up” but not draining is an outage. Metrics: lag, unacked, memory, disk, connections — same instinct as DB lock waits.

### Observability and SRE

The stack is not “we installed Grafana.” I stand up the path and keep it useful on call: **Prometheus + Alertmanager**, **Grafana** (dashboards and alert rules), **VictoriaMetrics**-class, exporters (node, kube-state, blackbox, cloud-provider). Logs: **OpenObserve** + **OpenTelemetry Collector**, **Loki** (Promtail / Vector / Fluent Bit), **ELK / OpenSearch** (Elasticsearch, **Logstash**, Kibana, Filebeat), **Graylog**. Traces: **Jaeger**, Zipkin-class, OTel. Retention, object-store backends, saved queries for L2, pages that match SLI. Same Cisco-style loop: gather metrics/logs/traces, isolate the layer, fix, document.

---

## Shape of the estates: 50+ services vs heavy JVM monoliths

Both showed up. The tuning is different; the ownership is not.

### Microservices (50+)

Estates with **fifty-plus microservices**: many pipelines, many images, many probes, many ways to break a release train.

What that actually means day to day:

- A deploy graph (what may go first, what must wait for the contract)
- Shared libraries and base images so you are not patching 50 Dockerfiles by hand
- Tracing / correlation so “user cannot pay” is not 50 log greps
- Resource requests that do not lie; noisy neighbours; HPA that does not flap
- A broker and a config story, or the mesh is theatre

This is why Git layout, promotion branches, and secrets (Vault / ESO) are not style — they are how 50 services stay shippable.

### Heavy monoliths (few backends, deep JVM)

The other shape: **one or two large backends** that *are* the product. Restarting the Deployment is not a strategy. The engine has to be understood.

**Tomcat / servlet** (and the JVM under it): thread pool vs connector (`maxThreads`, accept queue, timeouts), connection to the DB pool so you do not deadlock the heap waiting on JDBC, keep-alive vs load balancer idle timeouts.

**When it is sick:**

| Artefact | What I use it for |
|----------|-------------------|
| Heap dump | Who holds the RAM: leak, cache gone feral, duplicate classloaders, a report that materialised a million rows |
| Thread dump / stack | Deadlock, pool exhaustion, all threads stuck in the same JDBC or HTTP call, GC storm as a symptom |
| GC logs | Pause vs throughput; “we added RAM” vs “we need a different collector or less allocation” |

That is the same Cisco-style loop as a downed VM: define, gather (dump + metrics + last change), analyze, eliminate, test a small JVM or Tomcat knob, document so the next dump is faster. I do not pretend every dump is a novel — I do pretend the dump is evidence, not folklore.

---

## Education

**Bachelor of Science** in **Information Systems and Technologies** (Russian classifier **09.03.02**).

**University:** The Bonch-Bruevich Saint Petersburg State University of Telecommunications (SPbSUT / СПбГУТ им. проф. М.А. Бонч-Бруевича). Direction: Information Systems and Technologies (ИСиТ).

The programme was not theory-only. Coursework and labs included:

| Track | What that meant in practice |
|-------|-----------------------------|
| **Cisco** | Switching, routing, campus LAN/WAN labs; the same seven-step troubleshooting loop used later on production incidents |
| **Servers and networks** | Linux and Windows hosts, addressing, services, the unglamorous part of keeping a lab or small office online |
| **Windows Server at IT companies** | During studies: real-company work on Windows Server estates (AD-adjacent, file/print, day-2), not only campus VMs |

That is why hardware/OS depth and Cisco-style incident method in this lab are not a hobby add-on. They started in the degree and internships, then moved into platform work.

---

## What a hiring lead can take from this

- **Six years**, senior in platform niches, not a title inflation story
- **De facto lead** when the work needed it (train, delegate, own the result) without requiring the word Lead on the badge
- Comfortable **under a PM, a CTO, a team lead, or a project-wide tech lead**
- Comfortable **in a large team** and as the **single platform owner** on one or several products
- **Payments / SBP-class**, **treasury / trade-finance**, **blockchain**, **delivery e-commerce**, **Atlassian / Nextcloud / 1C**, **document AI**, **enterprise ITSM/EDO**, **multi-tenant Deckhouse**
- Build/deploy for **Java, Kotlin, .NET, Go, Python, PHP, Node, 1C**; gates with **SonarQube, Trivy, OSV-Scanner**
- **Jenkins** (plugins, workers) including **dedicated-VM agents → Kubernetes**; **GitLab CI + Argo CD**; **Azure DevOps**; **Helm + werf**
- Data and glue: **Kafka / Debezium / Rabbit / NATS / Artemis / Redis**; **PG/Patroni, MySQL, MSSQL, Oracle, Mongo, ClickHouse**; **Superset, Supabase, Airflow, n8n, NiFi**; **Harbor, MinIO, Ceph**; **Vault, Keycloak, Teleport**
- Observability / SRE: **Prometheus, Alertmanager, Grafana**, **OpenObserve + OTel Collector**, **Loki**, **ELK / Logstash / Kibana**, **Graylog**, **Jaeger**
- **CI catalog:** Terraform / guest init → Ansible → Vault → monitoring → docs, plus Java and other builds, publish, Sonar/Trivy/OSV, auto MR, deploy, revoke/cleanup. **Jenkins** (plugins, K8s workers) and **GitLab CI + Argo CD**. Detail: [`../iac/ci/`](../iac/ci/)
- **Huawei compute catalog:** CCE, RDS, GitLab/Vault/AppSec/Teleport ECS in a root that catalogs sibling Terragrunt network state. Detail: [`../iac/terraform/cloud-ru-compute/`](../iac/terraform/cloud-ru-compute/)
- **Payments identity Ansible:** Swarm autodeploy of AM / IG / Redis / Postgres, same roles for Kubernetes. Detail: [`../reference/ansible-payments-idplat/`](../reference/ansible-payments-idplat/)
- **Education:** B.Sc. 09.03.02 Information Systems and Technologies, SPbSUT (Bonch-Bruevich); Cisco labs, campus servers/networks; Windows Server practice at IT companies during studies

Cloud, Kubernetes, DBMS, SLA, and security defaults: [root README](../README.md) and [positioning](positioning.md).
