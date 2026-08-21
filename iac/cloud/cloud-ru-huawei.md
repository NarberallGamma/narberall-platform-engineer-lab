# cloud.ru / Huawei Cloud

**Business:** AWS-shaped platform in days; non-prod can **park at night**. Planned target for a seamless VK → Advanced move. Foreign-reader class note below is unchanged.

**Class:** Huawei Cloud (AWS-shaped). Provider in samples: `sbercloud`.  
**Role:** Platform Engineer, end-to-end ownership (greenfield and brownfield).

## What I owned

- Project / IAM baseline, VPC, subnets, routes, security groups, peering, EIP, VIP
- Compute (ECS / EC2-class), load-balancer adjacent VMs (GitLab, Vault, Teleport, app hosts)
- Managed Kubernetes (CCE / EKS-class) and node pools I operated
- RDS PostgreSQL HA, logical DBs and users
- DMS Kafka (instance, topics, users)
- OBS object storage (S3-compatible)
- Terragrunt DRY live (per-unit state) and multi-env Terraform roots
- Import of hand-built estates into state until `plan` is clean

**AWS mapping:** VPC, ECS→EC2, CCE→EKS, RDS, OBS→S3, DMS→MSK-class. Day-to-day work transfers to AWS hiring filters.

## Terraform in this lab

| Path | What |
|------|------|
| [`../terraform/cloud-ru-huawei/`](../terraform/cloud-ru-huawei/) | Cloud folder (stacks + Terragrunt live) |
| [`../terraform/cloud-ru-huawei/stacks/multi-env-root/`](../terraform/cloud-ru-huawei/stacks/multi-env-root/) | Multi-env root: network, ECS, CCE, RDS, Kafka, OBS |
| [`../terraform/cloud-ru-huawei/live/`](../terraform/cloud-ru-huawei/live/) | Terragrunt live sample (`env-dev` units) |
| [`../terraform/cloud-ru-compute/`](../terraform/cloud-ru-compute/) | **Second estate:** compute catalog (CCE, RDS, purpose ECS). Network stays in sibling Terragrunt live |
| [`../terraform/modules/`](../terraform/modules/) | Reusable `sbercloud` modules consumed by those stacks |
| [`../terraform/examples/greenfield-platform/`](../terraform/examples/greenfield-platform/) | Minimal module compose |
| [`../terraform/examples/brownfield-import/`](../terraform/examples/brownfield-import/) | Import checklist |

Inventory and import notes for the compute catalog: [`../terraform/cloud-ru-compute/ESTATE.md`](../terraform/cloud-ru-compute/ESTATE.md), case study [`../../case-studies/07-huawei-compute-catalog.md`](../../case-studies/07-huawei-compute-catalog.md).

Resource types: [`../terraform/RESOURCES.md`](../terraform/RESOURCES.md)

Cluster Helm: [`../helm/`](../helm/).

## Cloud API operators

Terraform creates the account. These images call the same Huawei-class API after apply.

| Path | Job |
|------|-----|
| [`../docker/images/operators/hibernate/`](../docker/images/operators/hibernate/) | Night-park stop/start on CCE workers and ECS. Ansible `docker_app` deploys the slug ([case 10](../../case-studies/10-ansible-estate.md)). Review: [`../../architecture/02-finops-night-park.md`](../../architecture/02-finops-night-park.md) |
| [`../docker/images/operators/cloud-metrics/`](../docker/images/operators/cloud-metrics/) | CloudEye exporter **Dockerfile only**. Go `src/` is not in git. Helm overlay scrapes SYS.RDS / SYS.DCS / SYS.DMS |
| [`../docker/images/operators/cloud-status/`](../docker/images/operators/cloud-status/) | Cloud.ru status `/metrics`. Owner HTTP client is in git |

Calendar inputs sketch: [`../terraform/examples/night-park/`](../terraform/examples/night-park/).

## Keywords

Huawei Cloud, cloud.ru, Terraform, Terragrunt, VPC, ECS, CCE, Kubernetes, RDS, Kafka, OBS, IAM, brownfield import, remote state, modules, multi-env, night-park, hibernate, CloudEye
