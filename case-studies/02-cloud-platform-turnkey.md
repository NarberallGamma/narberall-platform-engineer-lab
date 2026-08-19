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
        ├── iac/terraform/modules
        ├── cloud-ru-huawei/stacks/multi-env-root  (dev / preprod / prod)
        ├── cloud-ru-huawei/live                   (Terragrunt, per-unit state)
        └── aws/root + aws/accounts + aws/live
                │
                ▼
        remote state (S3-compatible)
                │
                ▼
        Kubernetes (built and operated) + CI/CD + apps + monitoring
```

## What shipped

- Cloud baseline: IAM/project settings, VPC, routing, security groups from zero
- Infra as code: Terraform (and Terragrunt where multi-project DRY mattered); layout split by cloud / modules / live so a new engineer and audit can follow it
- Modules: reusable network and compute building blocks
- Kubernetes: clusters I stood up and accompanied (managed Huawei/cloud.ru CCE-class and self-hosted / bare-metal where needed)
- CI/CD: pipelines delivering apps into those clusters (**Jenkins**; **GitLab CI + Argo CD** for branch/tag GitOps); secrets via Vault / protected CI / ESO-class patterns, not files in git
- Host and IAM hardening as part of the first delivery (users, rights, EDR where the estate uses it)
- Docs and monitoring handoff as part of platform delivery

## Results

- New environments described as code instead of console clicks
- Same module patterns reused across projects (faster next stand)
- Clear ownership: one engineer accountable for design → apply → operate → handoff

## Stack and platforms

Terraform, Terragrunt, remote state (S3/OBS-compatible), Huawei Cloud class / cloud.ru (`sbercloud`, AWS-shaped), VMware Cloud Director (`vmware/vcd`), AWS, Google Cloud, Hetzner, Proxmox, bare metal, Linux, Docker/Kubernetes, Ansible for day-2 hosts

**Note:** cloud.ru is Huawei Cloud class; day-to-day work maps to AWS skills (VPC, EC2-class compute, EKS-class Kubernetes, RDS, S3). cloud.ru VMware is a separate VCD API. See [case 06](06-vmware-vcd-greenfield.md).

## Links

- Cloud experience: [`iac/cloud/`](../iac/cloud/)
- Modules: [`iac/terraform/modules/`](../iac/terraform/modules/)
- Huawei-class multi-env root: [`iac/terraform/cloud-ru-huawei/stacks/multi-env-root/`](../iac/terraform/cloud-ru-huawei/stacks/multi-env-root/)
- Huawei-class Terragrunt live: [`iac/terraform/cloud-ru-huawei/live/`](../iac/terraform/cloud-ru-huawei/live/)
- AWS: [`iac/terraform/aws/`](../iac/terraform/aws/)
- Greenfield example: [`iac/terraform/examples/greenfield-platform/`](../iac/terraform/examples/greenfield-platform/)
- Day-2 Ansible: [`iac/ansible/`](../iac/ansible/)
- VCD greenfield + CI: [`06-vmware-vcd-greenfield.md`](06-vmware-vcd-greenfield.md), [`iac/ci/`](../iac/ci/)
