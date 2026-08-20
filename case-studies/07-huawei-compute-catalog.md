# Case study: Huawei-class compute catalog (split state)

**Context:** cloud.ru Advanced (Huawei Cloud class); network already in Terragrunt live; compute still click-ops  
**Timeline:** Inventory, catalog, import, then one new VM in the same root  
**Role:** Platform Engineer (sole IaC owner for the compute slice)

This is **proof** that Huawei-class work in this lab is not only a generic multi-env stack. A second estate already had VPC, peering, and NGFW in a sibling Terragrunt live (`live/<env>/<unit>`). CCE, RDS, GitLab, Vault, and AppSec were still console-built. I described them as a catalog + purpose files, imported until `plan` was clean, then created a Teleport DB-agent VM through the same root.

Not a second 70-VM OpenStack story. That proof is [case 05](05-legacy-estate-as-code.md).

## Challenge

One OBS-class bucket already held Terragrunt state under `live/`. A naive second root that also declared VPC would fight that state or recreate production network. CCE node-pool ECS and the NGFW VM had to stay out. RDS required a password in the provider schema even though the live password must not sit in git. Existing ECS often had an empty or leftover keypair; Terraform must not pretend it can push a key onto a running host.

## Architecture

See diagram: [`diagrams/case-studies/07-huawei-compute-catalog.md`](../diagrams/case-studies/07-huawei-compute-catalog.md)

```text
1) Sibling Terragrunt live owns VPC, subnet, route, peering, EIP, VIP, NGFW
2) Catalog maps those IDs (no sbercloud_vpc resource in this root)
3) Purpose files: cce.tf, rds.tf, ecs-gitlab / vault / appsec / test
4) Import compute addresses; do_not_import lists live/* leftovers
5) plan until No changes (no apply to "fix" the estate)
6) New VM (Teleport): key_pair from catalog, prevent_destroy only
7) Audit stack: same maps, no resource, second backend key
```

Honest scope: Istio / ESO live in cluster-resources, not this root. Kafka / OBS stay in the generic Huawei folder when that estate uses them.

## What shipped

- Compute root: 3 CCE, 3 RDS PostgreSQL 17 (HA on prod/preprod), 10 imported ECS + boot volumes, 1 created Teleport host
- Catalog: 6 VPCs, 9 subnets, SG / flavor / AZ / image / keypair maps
- Remote state: `platform/deploy` and `platform/audit` next to `live/`, never overlapping
- Guardrails: `prevent_destroy`, brownfield `ignore_changes`, `do_not_import`
- Public lab: sanitized tree with fake UUIDs and documentation CIDRs

## Results

- Click-ops compute has a source of truth without touching NGFW or node-pool ECS
- Next host is another `ecs-*.tf` + the project keypair, not a new console ritual
- Audit can print IDs without a write stack
- Same AWS-shaped model as the generic Huawei folder (VPC, ECS/EC2, CCE/EKS, RDS, OBS/S3)

## Stack

Terraform, `sbercloud` 1.12.18, OBS S3 backend, CCE, RDS PostgreSQL, ECS, EVS, catalog child-module, import workflow

**Note:** cloud.ru Advanced is **Huawei Cloud class**. Different API from VK Cloud (`vkcs`) and from VMware Cloud Director (`vcd`). Transferable AWS-shaped experience.

## Links

- Sanitized code: [`iac/terraform/cloud-ru-compute/`](../iac/terraform/cloud-ru-compute/)
- Inventory: [`iac/terraform/cloud-ru-compute/ESTATE.md`](../iac/terraform/cloud-ru-compute/ESTATE.md)
- Cloud page: [`iac/cloud/cloud-ru-huawei.md`](../iac/cloud/cloud-ru-huawei.md)
- Generic Huawei stacks: [`iac/terraform/cloud-ru-huawei/`](../iac/terraform/cloud-ru-huawei/)
- Related brownfield: [`04-terraform-brownfield-import.md`](04-terraform-brownfield-import.md)
- Related OpenStack-class legacy: [`05-legacy-estate-as-code.md`](05-legacy-estate-as-code.md)
- Ansible on the same class of estate: [`10-ansible-estate.md`](10-ansible-estate.md)
- Helm / GitOps on the same class of estate: [`11-helm-estate.md`](11-helm-estate.md)
