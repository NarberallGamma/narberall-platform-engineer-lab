# What business gets (days, cheaper, simpler)

This page is the hiring filter for founders, PMs, and CTOs. Engineers still start at [`../iac/`](../iac/) and the sanitized `.tf`. Existing cloud notes, resource maps, and case studies stay as they are. This file only states the **outcome**.

I talk to business first: **can the infra do what the product needs**, **how fast**, **how short the window**, **does the SLA hold**, **is it written down**. The Terraform and Kubernetes are how that outcome is delivered, not the product. Moving clouds is one skill I do quickly; it is not the headline.

## The offer in one screen

| Need | What I actually do | Typical calendar |
|------|--------------------|------------------|
| Empty project or rack | IAM, network, compute, data, Kubernetes, CI, docs, monitoring | **Days to a couple of weeks**, not a quarter of workshops |
| Keep it alive | Accompany: incidents, HA, brokers, DBMS, identity. **Minimal windows**, **~99.9% SLA** | Same day for P1; documented after |
| Nobody wrote it down | Runbooks, diagrams, inventory, audit-walkable Git | Days, in parallel with the first apply |
| Hand-built estate | Audit, inventory, import or wrap, runbooks, alerts | Days to first clean `plan`; weeks to stop click-ops |
| Bill too high | Right-size, kill idle, **park non-prod at night** (start/stop schedules on Huawei-class / cloud.ru and the same idea on AWS). Host proof: [`../iac/ansible/`](../iac/ansible/), [case 10](../case-studies/10-ansible-estate.md) | First cuts in days; schedule lives in git |
| Paper and tickets are slow | **OCR + LLM** so accounting, analysts, and developers stop retyping PDFs. Private GPU API + Nextcloud/n8n on one Ansible tree: [case 01](../case-studies/01-ai-llm-platform.md), [`../iac/ansible/reference/ansible-llm-collab/`](../iac/ansible/reference/ansible-llm-collab/) | Usable API in 1–2 weeks (see packages) |
| GPU / chat / RAG | Local Ollama / vLLM-class serve, vector store, optional Karpenter-class GPU scale | Sprint, not a research programme |
| Engineers paste tenant data or click the same ops | Multi-agent desk: Cursor, Claude Code, Codex, local LLM; MCP + wrappers. **Same kit on Linux, macOS, or WSL** | Hours to a day on a new laptop |
| On-call clicks Grafana / Jira / Vault for every change | I speak those **product APIs**. New views and alert rules the same day. Scripts + agents for the rest | Hours for a view; days to stop click-ops |
| Must move clouds (when asked) | Same platform shape on the next API. I do this **fast**; many treat it as a year. Example: VK Cloud / NOVA-class → Huawei-class Advanced | Design in days; window in hours |

International contracts: the same conversation. Class of cloud (AWS-shaped Huawei, OpenStack, VCD, Selectel) is a footnote so a non-RU buyer can map the skill. The buying question is still: **when does the product ship, and what does it cost to keep on**.

Full six-year narrative: [`experience.md`](experience.md). Diagrams for managers: [`../architecture/`](../architecture/).

## Faster

- Greenfield: apply from reusable modules and a one-button host CI (Terraform → Ansible → Vault → metrics → docs).
- Legacy: import until `plan` is clean. Proof already in the lab: [case 05](../case-studies/05-legacy-estate-as-code.md) (70+ VMs).
- CI: **Jenkins** and **GitLab CI + Argo CD** so a branch or tag is the release, not a meeting.
- Cluster package: Helm + Argo bootstrap on an existing cluster, plus one richest product chart per mechanic. Proof: [`../iac/helm/`](../iac/helm/), [`../iac/helm/apps/`](../iac/helm/apps/), [case 11](../case-studies/11-helm-estate.md).
- Images and Compose: one richest Dockerfile per mechanic, then Helm or `compose up`. Proof: [`../iac/docker/`](../iac/docker/), [case 12](../case-studies/12-docker-images.md).
- AI: OCR/LLM is a **multiplier** on document flow (finance, legal, analysts) and on developer/ops questions. Not a demo chatbot.
- Workstation: MCP + scripts so Terraform, Ansible, tickets, and GPU jobs run from Cursor, Claude Code, Codex, or a local-model wrapper. That is current practice. The same charts, playbooks, CI, and bash I still write by hand when required: about **four years** of that work predates coding agents, and much of the public lab is from then. Agents make the calendar shorter. They are not a substitute for having done the job. Bootstrap is bash, Docker, and env files, **not a Windows/WSL lock-in**.
- Monitoring and the rest of the estate are **APIs I already use**: Grafana (new views the same day), Prometheus / VictoriaMetrics, OpenObserve, Elasticsearch, Vault, Argo CD, JSM, GitLab, n8n. Proof: [`sre/`](sre/), [`../architecture/05-sre.md`](../architecture/05-sre.md), [case 10](../case-studies/10-ansible-estate.md) (host scrape), [case 11](../case-studies/11-helm-estate.md) (in-cluster overlay). Tokens and agents: [`security-ai.md`](security-ai.md).

## Cheaper

- Idle non-prod is the usual leak. I have run **scheduled power-off / power-on** on Huawei-class (cloud.ru) estates so nights and weekends do not pay for full ECS/CCE as if they were prod.
- Right-size disks, flavors, and replicas after an audit; cut obvious waste before buying a FinOps platform.
- Karpenter-class / node-pool scale: GPU and burst workers exist when a job runs, not 24/7.

## Simpler

- One owner who can **stand up and accompany** whatever the estate needs. Handoff is runbooks and diagrams, not a Slack channel that dies after invoice.
- Layout that audit can walk (IAM, secrets, who applied prod). Security in the first week so a later "hardening project" is not a second contract.
- Cloud move when the business asks: same workloads, new API, **short freeze**. I already treat this as days-plus-a-window, not a rewrite year. Both sides as code in the lab: [`../iac/terraform/vkcloud/`](../iac/terraform/vkcloud/), [`../iac/terraform/cloud-ru-huawei/`](../iac/terraform/cloud-ru-huawei/), [`../iac/terraform/cloud-ru-compute/`](../iac/terraform/cloud-ru-compute/).

## What I do not sell here

A dump of private client trees. A claim that every GPU cluster is public. A 15-minute miracle with no credentials or DNS. What is published is enough to see the **shape** and the **calendar**.
