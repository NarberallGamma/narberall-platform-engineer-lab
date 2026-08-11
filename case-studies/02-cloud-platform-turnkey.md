# Case study: Cloud platform turnkey (Terraform from zero)

**Context:** Multi-environment cloud platforms (FinTech and adjacent), greenfield IaC adoption  
**Timeline:** Ongoing across concurrent projects  
**Role:** Platform Engineer (end-to-end ownership)

## Challenge

Several platforms needed reproducible infrastructure with no prior Terraform baseline. Environments were created by hand or with one-off scripts. Delivery required VPC/network, compute, managed data services, and a path to Kubernetes and GitOps without locking the team into click-ops.

## Architecture

See diagram: [`diagrams/case-studies/02-cloud-platform-turnkey.md`](../diagrams/case-studies/02-cloud-platform-turnkey.md)

```text
modules (vpc, subnet, route, compute, ...)
        │
        ├── pattern A: multi-env Terraform root (dev / preprod / prod files)
        └── pattern B: Terragrunt live (per-unit state, DRY includes)
                │
                ▼
        remote state (S3-compatible object storage)
                │
                ▼
        cloud resources + docs + monitoring handoff
```

## What shipped

- Infra: introduced Terraform (and Terragrunt where multi-project DRY mattered) from zero
- Modules: reusable network and compute building blocks
- App edge: platform ready for services, adapters, and GitOps workloads
- Docs: layout README, backend/provider examples, operator notes
- Monitoring: observability wired as part of platform delivery (see monitoring starter)

## Results

- New environments described as code instead of console clicks
- Same module patterns reused across projects (faster next stand)
- Clear ownership: one engineer accountable for design → apply → handoff

## Stack

Terraform, Terragrunt, remote state (S3/OBS-compatible), cloud.ru-class provider (`sbercloud`), modules, Linux, Docker/Kubernetes adjacent delivery, Ansible for day-2 hosts

## Links

- Modules: [`terraform/modules/`](../terraform/modules/)
- Multi-env pattern: [`terraform/stacks/multi-env-root/`](../terraform/stacks/multi-env-root/)
- Terragrunt pattern: [`terraform/stacks/terragrunt-live/`](../terraform/stacks/terragrunt-live/)
- Greenfield example: [`terraform/examples/greenfield-platform/`](../terraform/examples/greenfield-platform/)
