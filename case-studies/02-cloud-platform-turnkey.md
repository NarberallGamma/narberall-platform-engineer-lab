# Case study: Cloud platform turnkey (Terraform from zero)

**Context:** Multi-environment cloud platforms (FinTech and adjacent), greenfield adoption  
**Timeline:** Ongoing across concurrent projects  
**Role:** Platform Engineer (end-to-end ownership)

## Challenge

Platforms needed reproducible infrastructure with no prior Terraform baseline. Environments were created by hand or with one-off scripts. Delivery required project IAM, VPC/network, compute, managed data services, and a path to Kubernetes and CI/CD without locking the team into click-ops.

## Architecture

See diagram: [`diagrams/case-studies/02-cloud-platform-turnkey.md`](../diagrams/case-studies/02-cloud-platform-turnkey.md)

```text
IAM / project baseline
        │
        ▼
VPC / subnets / routes / security
        │
        ├── modules (vpc, subnet, route, compute, ...)
        ├── stack A: multi-env Terraform root (dev / preprod / prod)
        └── stack B: Terragrunt live (per-unit state, DRY includes)
                │
                ▼
        remote state (S3-compatible)
                │
                ▼
        Kubernetes (built and operated) + CI/CD + apps + monitoring
```

## What shipped

- Cloud baseline: IAM/project settings, VPC, routing, security groups from zero
- Infra as code: Terraform (and Terragrunt where multi-project DRY mattered)
- Modules: reusable network and compute building blocks
- Kubernetes: clusters I stood up and accompanied (managed Huawei/cloud.ru CCE-class and self-hosted / bare-metal where needed)
- CI/CD: pipelines delivering apps into those clusters
- Docs and monitoring handoff as part of platform delivery

## Results

- New environments described as code instead of console clicks
- Same module patterns reused across projects (faster next stand)
- Clear ownership: one engineer accountable for design → apply → operate → handoff

## Stack and platforms

Terraform, Terragrunt, remote state (S3/OBS-compatible), Huawei Cloud class / cloud.ru (`sbercloud`, AWS-shaped), AWS, Google Cloud, Hetzner, VMware, Proxmox, bare metal, Linux, Docker/Kubernetes, Ansible for day-2 hosts

**Note:** cloud.ru is Huawei Cloud class; day-to-day work maps to AWS skills (VPC, EC2-class compute, EKS-class Kubernetes, RDS, S3).

## Links

- Platforms index: [`terraform/platforms/`](../terraform/platforms/)
- Modules: [`terraform/modules/`](../terraform/modules/)
- Multi-env stack: [`terraform/stacks/multi-env-root/`](../terraform/stacks/multi-env-root/)
- Terragrunt stack: [`terraform/stacks/terragrunt-live/`](../terraform/stacks/terragrunt-live/)
- Greenfield example: [`terraform/examples/greenfield-platform/`](../terraform/examples/greenfield-platform/)
- Multi-cloud notes: [`terraform/stacks/multi-cloud-notes/`](../terraform/stacks/multi-cloud-notes/)
