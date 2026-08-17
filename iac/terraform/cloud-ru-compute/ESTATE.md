# Huawei-class compute catalog (cloud.ru Advanced)

Sanitized picture of a **second Huawei-class estate**: network and NGFW already lived in Terragrunt `live/*`. This root described **compute that was still click-ops** (CCE, RDS, GitLab, Vault, AppSec) and imported it until `plan` was clean. A new Teleport DB-agent VM was then added as a normal `resource` (keypair on create).

No client names, no real UUIDs, no production hostnames. Private tree matches this layout. This file is the hunter-facing inventory.

This is **not** a second 70-VM OpenStack story. That proof is [`../vkcloud/ESTATE.md`](../vkcloud/ESTATE.md). This page is the Huawei / AWS-shaped proof of **split state + catalog + purpose ECS**.

## Scale (one project)

| Item | In the private estate | Published here |
|------|------------------------|----------------|
| VPC | **6** (prod, preprod, dev, public, appsec, ngfw). Owned by Terragrunt live | Catalog IDs + documentation CIDRs |
| Subnets | **9** (5 named + 4 NGFW: untrust / trust / mgmt / ha) | Catalog IDs + documentation CIDRs |
| CCE clusters | **3** (dev single-master, preprod/prod three masters, v1.34-class) | All three in `cce.tf` |
| CCE node-pool ECS | Present in cloud. **Not imported** as `compute_instance` | Listed as out of scope |
| RDS PostgreSQL | **3** (prod/preprod HA async, dev single). PG 17 | All three in `rds.tf` |
| Standalone ECS | **10** imported + **1** created (Teleport) | All purpose files |
| EVS boot volumes | **10** imported with the matching ECS | Same files |
| Security groups | Full project SGs as keys (NGFW, platform, AppSec tools, CCE node/control) | Catalog keys, fake UUIDs |
| Flavors / AZ / images / volume types | Full maps used by every file | Public catalog names |
| `terraform plan` after import | **No changes** (no apply to "fix" the estate) | Pattern only; this slice is not wired to a live project |
| New VM after import | Teleport DB agent: `key_pair` from catalog, `prevent_destroy` only | `ecs-teleport.tf` |

Network, default route via NGFW, peering, EIP, VIP, and the Palo Alto-class NGFW ECS stay in the sibling Terragrunt live. This root must not declare them as `resource`.

## Purpose groups (compute root)

| Purpose (public label) | Hosts | What that class is |
|------------------------|-------|--------------------|
| GitLab | 2 (dev + prod) | Self-hosted Git + CI adjacent; large boot disk on dev |
| Vault | 2 (dev + prod) | Secrets plane next to CCE (ESO in cluster-resources, not this root) |
| AppSec | 4 | Nessus, Semgrep, Dependency-Track, DefectDojo in a dedicated VPC |
| Access (Teleport-class) | 1 new | DB agent on prod subnet; created after the import |
| Test / leftover | 2 | Stopped test ECS; kept in state so they are not click-ops again |
| CCE | 3 clusters | Overlay L2, RBAC. Node pools operated, not imported as ECS |
| RDS | 3 instances | Managed PostgreSQL; `db.password` required by the provider, `ignore_changes` on `db` |

k8s add-ons (Istio, ESO) live in a cluster-resources repo, not in this Terraform root.

## How the code is laid out

```text
cloud-ru-compute/
  README.md
  ESTATE.md
  IMPORT.md
  deploy/
    versions.tf
    provider.tf.example      # OBS-class S3 backend + sbercloud
    variables.tf             # AK/SK, region, project tag, RDS placeholder
    catalog.tf               # module "catalog" { source = "./variables" }
    locals_catalog.tf        # local.vpcs / subnets / flavors / az / ...
    cce.tf
    rds.tf
    ecs-gitlab.tf
    ecs-vault.tf
    ecs-appsec.tf
    ecs-test.tf
    ecs-teleport.tf
    outputs.tf
    terraform.tfvars.example
    variables/               # child-module maps (fake UUIDs)
  audit/
    catalog.tf               # same maps, no resource
    outputs.tf
    provider.tf.example
```

ECS / CCE / RDS files use **catalog keys**, not raw UUIDs:

```hcl
flavor_id          = local.flavors.s7n_2xlarge_2
availability_zone  = local.az.a
security_group_ids = [local.sg_ids.ngfw_untrust]
network {
  uuid        = local.subnets.dev
  fixed_ip_v4 = "10.10.4.10"
}
```

## Guardrails that stayed after import

- `lifecycle.prevent_destroy = true` on imported CCE, RDS, ECS, and EVS
- Brownfield `ignore_changes` on imported ECS: image, user_data, disks, leftover key_pair, tags, charging
- CCE: ignore kubeconfig / certs / version drift from the control plane
- RDS: ignore `db` (provider requires password; live password is not in git)
- New VMs: `key_pair = local.key_pairs.ecs_prod` (or ecs_dev / ecs_preprod). Terraform does not push a key onto an already-running host
- `do_not_import` map: NGFW ECS, EIPs, VIPs, custom route table, `live/` prefix
- Apply was **not** used to rewrite the estate. Goal: clean plan, then day-2 through code

## Remote state (one bucket, two prefixes)

| Prefix | Owner | Contents |
|--------|-------|----------|
| `live/<env>/<unit>/` | Sibling Terragrunt (network / NGFW) | VPC, subnet, route, peering, EIP, VIP, NGFW ECS |
| `platform/deploy/` | This root | CCE, RDS, standalone ECS |
| `platform/audit/` | This root | Catalog outputs only |

OBS checksum workaround on Terraform 1.11+: `AWS_REQUEST_CHECKSUM_CALCULATION=when_required` and `AWS_RESPONSE_CHECKSUM_VALIDATION=when_required`.

## Keywords

Huawei Cloud, cloud.ru, sbercloud, CCE, RDS, ECS, GitLab, Vault, Teleport, AppSec, Nessus, Semgrep, Dependency-Track, DefectDojo, catalog, split state, Terragrunt live, brownfield import, No changes, prevent_destroy, do_not_import
