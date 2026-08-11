# Narberall: Platform Engineer Lab

**Platform Engineer. AI and turnkey cloud delivery.**

I design and ship platforms end to end: cloud project bootstrap (IAM, VPC, networking), compute, managed data, Kubernetes, CI/CD, application and utility code, documentation, and monitoring.  
This repo is my public lab: NDA-safe case studies, **sanitized Terraform / Terragrunt**, diagrams, and the portfolio site source.

**Live site:** _(add URL after first deploy)_  
**License:** MIT

---

## Why this is a curated lab (not full private trees)

Published IaC is a **curated showcase**: representative modules, roots, and resource examples from real delivery.

**Full client / employer Terraform trees are not published.** Reasons:

1. **Security and confidentiality** - real account IDs, hostnames, CIDRs, IAM bindings, and operational history must stay private  
2. **Size and history** - production IaC repos are often large, multi-year codebases; dumping them here would bury the signal under noise  

What you get instead: enough real `.tf` / Terragrunt to see that I can describe **an entire cloud platform as code**, plus a resource map in [`terraform/RESOURCES.md`](terraform/RESOURCES.md).

---

## Delivery scope (what I own)

I regularly stand up infrastructure **from zero** in public clouds and on premises:

1. Cloud / project baseline: accounts, IAM, networks (VPC / subnets / routing / security groups / peering)  
2. Compute and data: VMs, load balancers, managed DB, cache, object storage, messaging (Kafka-class)  
3. Kubernetes platforms I build and operate myself (managed CCE/EKS-class and self-hosted / bare metal where required)  
4. Edge and identity-adjacent pieces: DNS (Cloudflare), CDN/ACM patterns, CI users and roles  
5. CI/CD into those clusters, plus day-2 Linux/Ansible and observability  

**Cloud.ru note for international readers:** cloud.ru (and similar RU hyperscalers in this lab) is **Huawei Cloud class**. The resource model and day-to-day patterns closely follow **AWS** (VPC, ECS/EC2-class compute, CCE/EKS-class Kubernetes, RDS, OBS/S3, DMS/Kafka-class). That work is transferable AWS-shaped experience.

Also shipped platforms on **AWS**, **Google Cloud**, **Hetzner**, **OpenStack / Selectel**, **VMware**, **Proxmox**, and **bare-metal** servers in previous roles.

```mermaid
flowchart TB
  subgraph clouds [Clouds and compute I have delivered on]
    CR[cloud.ru Huawei-class]
    AWS[AWS]
    GCP[Google Cloud]
    HZ[Hetzner]
    OS[OpenStack Selectel]
    PX[Proxmox]
    VM[VMware]
    BM[Bare metal]
  end
  clouds --> Own[End-to-end ownership]
  Own --> IaC[Terraform Terragrunt]
  Own --> K8s[Kubernetes CI CD]
```

---

## Terraform / IaC (start here)

All Terraform and Terragrunt code lives in the top-level **[`terraform/`](terraform/)** directory.  
This is the main proof of cloud infrastructure as code in the repo.

| Go to | Why |
|-------|-----|
| [`terraform/README.md`](terraform/README.md) | IaC navigation hub |
| [`terraform/RESOURCES.md`](terraform/RESOURCES.md) | **Full picture:** clouds × resource types in code |
| [`terraform/platforms/`](terraform/platforms/) | Samples: cloud.ru/Huawei, AWS, OpenStack/Selectel, Proxmox, Cloudflare |
| [`terraform/stacks/multi-env-root/`](terraform/stacks/multi-env-root/) | Multi-env root: network, VMs, K8s, RDS, Kafka, OBS |
| [`terraform/stacks/terragrunt-live/`](terraform/stacks/terragrunt-live/) | Terragrunt DRY (cloud.ru-class) |
| [`terraform/stacks/aws-terragrunt-live/`](terraform/stacks/aws-terragrunt-live/) | AWS Terragrunt live (EKS, RDS, ElastiCache, …) |
| [`terraform/modules/`](terraform/modules/) | Reusable modules used by stacks |
| [`terraform/SANITIZE.md`](terraform/SANITIZE.md) | What never goes into git |

I introduce Terraform/Terragrunt from zero on greenfield platforms, and I import hand-built cloud into state until `plan` is clean.

```mermaid
flowchart TB
  subgraph lab [narberall-platform-engineer-lab]
    TF["terraform/ IaC showcase"]
    CS[case-studies]
    REF[reference apps ansible ai]
    PR[practice]
  end
  TF --> Hunter[Recruiter or lead]
  CS --> Hunter
  REF --> Hunter
```

```mermaid
flowchart LR
  subgraph tf ["terraform/"]
    ResMap[RESOURCES.md]
    Plat[platforms]
    Stacks[stacks]
    Mods[modules]
    Ex[examples]
  end
  ResMap --> Plat
  Plat --> Stacks
  Mods --> Stacks
  Stacks --> Ex
```

```mermaid
flowchart TB
  IAM[IAM and project baseline] --> VPC[VPC network security peering]
  VPC --> Compute[Compute LB data cache object storage]
  Compute --> Msg[Kafka-class messaging]
  Compute --> K8s[Kubernetes I build and run]
  Msg --> K8s
  K8s --> CICD[CI CD apps observability]
  Edge[Cloudflare DNS CDN ACM] --> CICD
  Bare[Bare metal VMware Proxmox] --> K8s
```

```mermaid
flowchart TB
  subgraph published [Published in this lab]
    Samples[Sanitized .tf and Terragrunt]
    Map[RESOURCES.md coverage map]
  end
  subgraph private [Kept private]
    Full[Full multi-year client trees]
    Secrets[Accounts hostnames real CIDRs]
  end
  Samples --> Signal[Clear signal for hiring]
  Map --> Signal
  private --> Protect[Security and readability]
```

---

## Repo map

| Path | What |
|------|------|
| [`terraform/`](terraform/) | **IaC: Terraform + Terragrunt** (platforms, stacks, modules, resource map) |
| [`case-studies/`](case-studies/) | Problem → architecture → result |
| [`packages/`](packages/) | Fixed-scope offers |
| [`reference/`](reference/) | Non-TF reference kits (AI compose, Ansible, monitoring, apps) |
| [`practice/`](practice/) | Workstation tooling + home lab |
| [`diagrams/`](diagrams/) | Architecture diagrams |
| [`site/`](site/) | Portfolio website source |
| [`docs/`](docs/) | Positioning, content guide |

---

## Case studies (IaC-related)

- [Cloud platform turnkey / Terraform from zero](case-studies/02-cloud-platform-turnkey.md)
- [Brownfield import into Terraform state](case-studies/04-terraform-brownfield-import.md)
- [AI / LLM platform](case-studies/01-ai-llm-platform.md)
- [Document AI pipeline](case-studies/03-document-ai-pipeline.md)

---

## Maintenance zones

See [`OWNERS.md`](OWNERS.md): work machine owns most paths; home machine fills only `practice/home-lab/` and `HOME_SLOT` files.

## Positioning

> Turnkey cloud and AI infrastructure: IaC, CI/CD, LLM/RAG stacks, apps, docs, and observability. AWS-shaped Huawei/cloud.ru depth plus AWS, GCP, Hetzner, OpenStack/Selectel, VMware, Proxmox, and bare metal.
