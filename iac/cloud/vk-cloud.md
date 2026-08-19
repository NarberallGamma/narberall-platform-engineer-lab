# VK Cloud (NOVA Cloud class)

**Business:** 70+ hand-built VMs became Terraform so click-ops stopped. **Planned** seamless move to Huawei-class Advanced (both sides already in this lab). Class notes below stay.

**Class:** NOVA Cloud (Kazakhstan). Under the hood: OpenStack (Nova / Cinder / Neutron / Keystone). Provider in samples: `vk-cs/vkcs`.  
**Role:** Platform Engineer. **Proof** of the [legacy claim](../../README.md#greenfield-and-legacy): I arrived on a **hand-built** VK Cloud (MCS) project (no Terraform), described the whole layout from zero, and imported live compute.

**VK Cloud note:** VK Cloud (MCS) is **NOVA Cloud class** (Kazakhstan). Under the hood the resource model is **OpenStack**: Nova compute, Cinder volumes, Neutron networks (VPC-equivalent), Keystone identity. Same mental model as Kazakhstan **NOVA Cloud** and other OpenStack IaaS (Selectel-class included). Different console and Terraform provider than Huawei-class cloud.ru (`sbercloud`) and than the Selectel sample in this lab.

**OpenStack mapping:** Nova → compute, Cinder → volumes, Neutron → VPC-equivalent, Keystone → identity. Day-to-day work transfers to NOVA Cloud KZ and other OpenStack IaaS hiring filters.

## What I owned

- The estate was already running (console / click-ops) **before I wrote a single `.tf` file**. No rebuild
- Read-only inventory of the live project, then a **full catalog from zero**: networks (VPC-equivalent), subnets, security groups, flavors, AZs, volume types, key pairs
- Purpose map and **70+ VMs** as resources (`vm-*.tf` by job: collaboration, identity / Windows, ERP-class, data, GPU/LLM, security, proxy, monitoring). Full private tree unpublished
- Import of **200+** addresses (instance + volume + attach) into S3-compatible remote state until `terraform plan` is **No changes**
- Duplicate empty Neutron networks renamed in console so instance import could resolve networks by name
- Honest scope cut: managed DBaaS and project object-storage buckets deferred when the service account lacked rights. Networks and SGs live in the catalog (described); compute is what was imported as resources

## Terraform in this lab

| Path | What |
|------|------|
| [`../terraform/vkcloud/`](../terraform/vkcloud/) | Sanitized root: catalog module, purpose-split VMs, brownfield lifecycle, import notes |
| [`../terraform/vkcloud/ESTATE.md`](../terraform/vkcloud/ESTATE.md) | NDA-safe inventory of the legacy estate (counts and purpose, not hostnames) |
| [`05-legacy-estate-as-code.md`](../../case-studies/05-legacy-estate-as-code.md) | Case study: inventory → code → import → clean plan |

Resource types: [`../terraform/RESOURCES.md`](../terraform/RESOURCES.md)

Related pattern (Huawei-class, different provider): [`04-terraform-brownfield-import.md`](../../case-studies/04-terraform-brownfield-import.md)

## Keywords

VK Cloud, MCS, NOVA Cloud, Kazakhstan, OpenStack, Nova, Cinder, Neutron, Keystone, vkcs, Terraform, brownfield, legacy proof, 70+ VMs, catalog from zero, VPC, security groups, import, remote state, prevent_destroy, GPU, Windows Server, collaboration
