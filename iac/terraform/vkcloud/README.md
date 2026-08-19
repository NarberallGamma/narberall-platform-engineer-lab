# Platform: VK Cloud (NOVA Cloud class)

**Class:** NOVA Cloud (Kazakhstan OpenStack IaaS). Under the hood: OpenStack Nova / Cinder / Neutron / Keystone. Provider: `vk-cs/vkcs`.

Sanitized brownfield root. Private estate: about 70 Nova VMs, 200+ Terraform addresses, clean `plan` after import. This folder is a **curated slice** (purpose files, fake UUIDs, documentation CIDRs) plus a **greenfield** vkcs module used for a security/metrics VM (Terragrunt unit).

Experience: [`../../cloud/vk-cloud.md`](../../cloud/vk-cloud.md)  
Inventory (counts, not hostnames): [`ESTATE.md`](ESTATE.md)  
Case study: [`../../../case-studies/05-legacy-estate-as-code.md`](../../../case-studies/05-legacy-estate-as-code.md)  
Map: [`../RESOURCES.md`](../RESOURCES.md)

| File | Resources |
|------|-----------|
| `variables/` | Catalog maps: networks, flavors, AZ, SG, volume types, key pairs |
| `catalog.tf` / `locals_catalog.tf` | Child module wired as `local.*` |
| `vm-collaboration.tf` | Atlassian-class app + wiki (boot volume, extra disks, attach) |
| `vm-identity.tf` | Windows DC-class instance |
| `vm-llm.tf` | GPU inference VM (V100-class flavor) |
| `vm-database.tf` | Self-managed DB VM + data volume |
| `vm-sec-monitor.tf` | Security / metrics VM via reusable module |
| `modules/compute_instance/` | Image-by-properties, cloud-init SSH keys, boot volume |
| `live/sec-monitor/` | Terragrunt unit + S3-compatible state sample |
| `brownfield.tf` | Lifecycle policy note |
| `IMPORT.md` | `terraform import` with fake IDs |
| `provider.tf.example` | vkcs provider + S3-compatible backend |

Provider: `vk-cs/vkcs` `~> 0.17.0`. Terraform `>= 1.5.0`.

Copy `provider.tf.example` to `provider.tf` (gitignored patterns for state). Fill `terraform.tfvars` from `terraform.tfvars.example`. Never commit real project IDs, usernames, or state.
