# cloud.ru compute catalog (Huawei Cloud class)

**Class:** Huawei Cloud (AWS-shaped). Provider: `sbercloud-terraform/sbercloud`.  
**Role:** Platform Engineer. Brownfield compute root next to a sibling Terragrunt network live.

This folder is a **curated, sanitized copy** of a live compute stack: CCE, RDS PostgreSQL, and purpose-split ECS (GitLab, Vault, AppSec, Teleport, test). VPC, subnet, peering, EIP, VIP, and NGFW stay in a **separate Terragrunt live** (`live/<env>/<unit>`). This root only **catalogs** those IDs. It does not declare `sbercloud_vpc` / `sbercloud_vpc_subnet`.

Experience: [`../../cloud/cloud-ru-huawei.md`](../../cloud/cloud-ru-huawei.md)  
Inventory (counts, not client names): [`ESTATE.md`](ESTATE.md)  
Import runbook: [`IMPORT.md`](IMPORT.md)  
Case study: [`../../../case-studies/07-huawei-compute-catalog.md`](../../../case-studies/07-huawei-compute-catalog.md)  
Generic Huawei stacks (network + Kafka + OBS in one root): [`../cloud-ru-huawei/`](../cloud-ru-huawei/)  
Map: [`../RESOURCES.md`](../RESOURCES.md)

| Path | What |
|------|------|
| `deploy/variables/` | Catalog maps: VPC, subnet, CCE/RDS/ECS IDs, flavors, AZ, SG, images, volume types, key pairs |
| `deploy/catalog.tf` / `locals_catalog.tf` | Child module wired as `local.*` |
| `deploy/cce.tf` | Three CCE clusters (dev / preprod / prod). Node-pool ECS not imported |
| `deploy/rds.tf` | Three PostgreSQL instances (HA on prod/preprod) |
| `deploy/ecs-gitlab.tf` | GitLab ECS + boot volume (dev + prod) |
| `deploy/ecs-vault.tf` | Vault ECS + boot volume (dev + prod) |
| `deploy/ecs-appsec.tf` | Nessus, Semgrep, Dependency-Track, DefectDojo |
| `deploy/ecs-test.tf` | Stopped test ECS (two stands) |
| `deploy/ecs-teleport.tf` | New Teleport DB-agent VM (create path, not import) |
| `audit/` | Read-only catalog outputs. No `resource` blocks |
| `IMPORT.md` | `terraform import` with fake IDs |

Provider: `sbercloud-terraform/sbercloud` `1.12.18`. Terraform `>= 1.11.0`.

Copy `deploy/provider.tf.example` to `deploy/provider.tf` locally. Fill `terraform.tfvars` from `terraform.tfvars.example`. Never commit real project IDs, AK/SK, or state.

Two remote-state keys in one OBS-class bucket:

| Stack | Backend key (sanitized) |
|-------|-------------------------|
| Network / NGFW (sibling repo) | `live/<env>/<unit>/terraform.tfstate` |
| This deploy root | `platform/deploy/terraform.tfstate` |
| This audit root | `platform/audit/terraform.tfstate` |

Keys under `live/` are out of scope. Resources already in that live must stay in `do_not_import`.
