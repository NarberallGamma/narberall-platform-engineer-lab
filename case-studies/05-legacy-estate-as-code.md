# Case study: Legacy estate as Terraform (VK Cloud / NOVA Cloud class)

**Context:** Hand-built NOVA Cloud class estate (VK Cloud / MCS, Kazakhstan OpenStack IaaS); years of console VMs, no IaC  
**Timeline:** Inventory, code from zero, import, clean plan in one delivery window  
**Role:** Platform Engineer (sole IaC owner for this estate)

This is **proof** of the [legacy claim](../README.md#greenfield-and-legacy) in the root README, not a second story. The README says I take over click-ops estates. Here is one: everything below was already running when I arrived; I wrote the Terraform.

## Challenge

Production collaboration, Windows identity, databases, GPU inference, and security VMs were already up. **Someone else had built them by hand** (console / click-ops). There was no Terraform, no remote state, and no map of "what this VM is for." Rebuild was not an option.

Goal: describe **the entire live layout from zero** (networks / VPC-equivalent, subnets, security groups, flavors, AZs, then **70+ VMs** by purpose), import compute into state, reach `terraform plan` with **no changes**, and leave a catalog a successor can extend.

See diagram: [`diagrams/case-studies/05-legacy-estate-as-code.md`](../diagrams/case-studies/05-legacy-estate-as-code.md)

## Architecture

```text
1) Read-only API inventory (Nova / Cinder / Neutron)
2) Purpose map (collaboration, identity, data, GPU, security, ...)
3) Catalog from zero: all networks (VPC-equivalent), subnets, security groups, flavors, AZ
4) 70+ VMs as `vm-*.tf` by purpose (catalog keys, not raw UUIDs)
5) terraform import for instance + volume + attach
6) Align HCL to state (NIC order, volume names, security_group_ids)
7) Short ignore_changes for provider quirks; prevent_destroy everywhere
8) terraform plan -> No changes. Apply is a separate, explicit decision.
```

Honest scope: managed DBaaS and object-storage buckets stayed out when the service account could not list or manage them. Empty duplicate Neutron networks were renamed in console so import could resolve the working nets by name.

## What shipped

- **Catalog from zero:** every network (VPC-equivalent), subnet, security group, flavor, AZ, volume type, and key pair in the project written as maps. VM files use keys (`local.networks.app`), not raw UUIDs
- **70+ VMs** as Terraform resources, grouped by purpose (identity, collaboration, data, GPU, security, ...), plus volumes and attaches (**200+** addresses in remote state)
- Public lab: curated four-VM slice plus the catalog pattern. Full private tree stays unpublished
- Docs: purpose inventory, import runbook, lifecycle policy
- Guardrails: `prevent_destroy`; flavor lock; no apply used as a "fix"

## Results

- Click-ops estate represented in code and state **without recreating** a single production VM or network
- `terraform plan` converged to no unintended changes
- Next changes (resize, replace, add) have a single source of truth: catalog + purpose files

## Stack

Terraform, `vk-cs/vkcs`, S3-compatible remote state, NOVA Cloud class / VK Cloud (OpenStack Nova / Cinder / Neutron / Keystone), brownfield import

**Note:** VK Cloud (MCS) is **NOVA Cloud class** (Kazakhstan). Under the hood the resource model is **OpenStack**: Nova compute, Cinder volumes, Neutron networks (VPC-equivalent), Keystone identity. That work transfers to NOVA Cloud KZ and other OpenStack IaaS.

## Links

- Sanitized code: [`iac/terraform/vkcloud/`](../iac/terraform/vkcloud/)
- Estate counts: [`iac/terraform/vkcloud/ESTATE.md`](../iac/terraform/vkcloud/ESTATE.md)
- Cloud page: [`iac/cloud/vk-cloud.md`](../iac/cloud/vk-cloud.md)
- Related Huawei-class import story: [`04-terraform-brownfield-import.md`](04-terraform-brownfield-import.md)
- Greenfield counterpart: [`02-cloud-platform-turnkey.md`](02-cloud-platform-turnkey.md)
