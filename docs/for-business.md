# What business gets (days, cheaper, simpler)

This page is the hiring filter for founders, PMs, and CTOs. Engineers still start at [`../iac/`](../iac/) and the sanitized `.tf`. Existing cloud notes, resource maps, and case studies stay as they are. This file only states the **outcome**.

I talk to business first: **time to a working platform**, **monthly cloud bill**, **how many people must babysit it**. The Terraform and Kubernetes are how that outcome is delivered, not the product.

## The offer in one screen

| Need | What I actually do | Typical calendar |
|------|--------------------|------------------|
| Empty project or rack | IAM, network, compute, data, Kubernetes, CI, docs, monitoring | **Days to a couple of weeks**, not a quarter of workshops |
| Hand-built estate | Audit, inventory, import or wrap, runbooks, alerts | Days to first clean `plan`; weeks to stop click-ops |
| Bill too high | Right-size, kill idle, **park non-prod at night** (start/stop schedules on Huawei-class / cloud.ru and the same idea on AWS) | First cuts in days; schedule lives in git |
| Must move clouds | Same platform shape on the next API; **planned seamless cutover** (example: VK Cloud / NOVA-class → Huawei-class Advanced) | Design in days; window in hours, not a rewrite year |
| Paper and tickets are slow | **OCR + LLM** so accounting, analysts, and developers stop retyping PDFs | Usable API in 1–2 weeks (see packages) |
| GPU / chat / RAG | Local Ollama / vLLM-class serve, vector store, optional Karpenter-class GPU scale | Sprint, not a research programme |

International contracts: the same conversation. Class of cloud (AWS-shaped Huawei, OpenStack, VCD, Selectel) is a footnote so a non-RU buyer can map the skill. The buying question is still: **when does the product ship, and what does it cost to keep on**.

Full six-year narrative: [`experience.md`](experience.md). Diagrams for managers: [`../architecture/`](../architecture/).

## Faster

- Greenfield: apply from reusable modules and a one-button host CI (Terraform → Ansible → Vault → metrics → docs).
- Legacy: import until `plan` is clean. Proof already in the lab: [case 05](../case-studies/05-legacy-estate-as-code.md) (70+ VMs).
- CI: **Jenkins** and **GitLab CI + Argo CD** so a branch or tag is the release, not a meeting.
- AI: OCR/LLM is a **multiplier** on document flow (finance, legal, analysts) and on developer/ops questions. Not a demo chatbot.

## Cheaper

- Idle non-prod is the usual leak. I have run **scheduled power-off / power-on** on Huawei-class (cloud.ru) estates so nights and weekends do not pay for full ECS/CCE as if they were prod.
- Right-size disks, flavors, and replicas after an audit; cut obvious waste before buying a FinOps platform.
- Karpenter-class / node-pool scale: GPU and burst workers exist when a job runs, not 24/7.

## Simpler

- One owner who can **stand up, accompany, and migrate**. Handoff is runbooks and diagrams, not a Slack channel that dies after invoice.
- Layout that audit can walk (IAM, secrets, who applied prod). Security in the first week so a later "hardening project" is not a second contract.
- Planned **VK Cloud → Advanced** (Huawei-class) style move: same workloads, new API, **seamless** from the user's point of view (DNS, data, freeze window). The lab already has both sides as code: [`../iac/terraform/vkcloud/`](../iac/terraform/vkcloud/), [`../iac/terraform/cloud-ru-huawei/`](../iac/terraform/cloud-ru-huawei/), [`../iac/terraform/cloud-ru-compute/`](../iac/terraform/cloud-ru-compute/).

## What I do not sell here

A dump of private client trees. A claim that every GPU cluster is public. A 15-minute miracle with no credentials or DNS. What is published is enough to see the **shape** and the **calendar**.
