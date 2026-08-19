# Legacy estate as code (VK Cloud / NOVA Cloud class)

Sanitized picture of a **hand-built** NOVA Cloud class estate (VK Cloud / MCS, OpenStack under the hood). This page is the **proof** of the [legacy claim](../../../README.md#greenfield-and-legacy): I did not create these VMs; I described what was already running, in Terraform, from zero.

No client names, no real UUIDs, no production hostnames. Private tree is larger. This file is the hunter-facing inventory.

## Scale (one project)

| Item | In the private estate (described from zero) | Published here |
|------|---------------------------------------------|----------------|
| Nova compute | **70+** instances brought into Terraform (managed DBaaS members excluded) | 4 imported purpose VMs + 1 greenfield sec-monitor module |
| Cinder volumes + attaches | **100+** volumes, **30+** attaches | boot + data disks on those 4 |
| Terraform addresses in state | **200+** (instance + volume + attach), imported | same resource types, curated |
| Networks (VPC-equivalent) | **all** project networks in a catalog (about 16, including empty Neutron duplicates renamed in console) | 4 catalog keys |
| Subnets | **all** project subnets (100+) | documentation CIDRs only |
| Security groups | **all** project SGs as keys (names + UUIDs) | 3 catalog keys |
| Flavors / AZ / volume types | full maps used by every VM file | subset of public catalog names |
| Purpose files in private root | about **15** `vm-*.tf` | 5 files (collaboration, identity, llm, database, sec-monitor) |
| `terraform plan` | **No changes** after import (no apply) | pattern only; this slice is not wired to a live project |

The networks, SGs, and VPC-equivalent were **already there** (console). The work was to write the catalog so VM code never hardcodes UUIDs, then import compute. Not a greenfield `apply` of empty VPCs.

AZ spread in the live project was multi-zone (four public VK Cloud AZs). Flavor catalog includes standard, NVMe, and GPU (V100-class) names from the provider.

## Purpose groups (legacy layout)

The running estate was not a greenfield VPC. **Years of console-built VMs before I arrived.** Code groups them by **job**, not by the order they were clicked:

| Purpose (public label) | Approx. VMs | What that class is |
|------------------------|-------------|--------------------|
| Windows identity / AD-class | ~17 | DC, federation, NPS, CA, office, backup-adjacent Windows |
| ERP / 1C-class | ~10 | Application and supporting Windows/Linux around 1C |
| Collaboration (Atlassian-class) | ~6 | Jira / Service Desk / wiki / related app hosts |
| Files (Nextcloud-class) | ~6 | File share, docker data, related app VMs |
| Databases (self-managed) | ~5 | Postgres-class and siblings on VMs (not DBaaS) |
| NGFW / security / EDR | ~8 | Firewall, scanners, security proxies |
| Monitoring | ~3 | Metrics / log / scanner hosts |
| Proxy / LB | ~3 | Edge proxy and load balancer VMs |
| Redis / Kafka-class | ~3 | Cache and broker VMs |
| Access (Teleport-class) | ~2 | Jump / access plane |
| Document capture | ~1 | Enterprise capture host |
| GPU / LLM | ~1 | Inference VM (V100-class flavor) |
| Misc | ~2 | Leftovers until purpose is proven |

Managed PostgreSQL (DBaaS) members were **inventoried then excluded** from Nova import. Object storage buckets were **not** imported (separate keys / IAM). Those stay out of this showcase on purpose.

## How the code is laid out

```text
vkcloud/
  versions.tf              # terraform + vkcs pin
  variables.tf             # Keystone auth (no secrets)
  catalog.tf               # module "catalog" { source = "./variables" }
  locals_catalog.tf        # local.networks / flavors / az / sg_ids / ...
  brownfield.tf            # note + shared lifecycle policy
  vm-collaboration.tf      # Atlassian-class sample
  vm-identity.tf           # Windows DC sample
  vm-llm.tf                # GPU inference sample
  vm-database.tf           # self-managed DB sample
  vm-sec-monitor.tf        # greenfield module (metrics / security)
  modules/compute_instance/
  live/sec-monitor/        # Terragrunt unit
  variables/               # child-module maps (fake UUIDs)
  IMPORT.md                # import addresses with fake IDs
  provider.tf.example      # backend + provider (copy locally)
```

VM files use **catalog keys**, not raw UUIDs:

```hcl
flavor_name        = local.flavors.gpu_v100
availability_zone  = local.az.gpu
security_group_ids = [local.sg_ids.default, local.sg_ids.app]
network {
  uuid        = local.networks.app
  fixed_ip_v4 = "10.10.2.18"
}
```

## Guardrails that stayed after import

- `lifecycle.prevent_destroy = true` on instance, volume, and attach
- Short `ignore_changes` on instance: `block_device` (provider Read vs managed boot volume), `flavor_name` / `flavor_id` (lock against accidental resize), `force_delete` / `stop_before_destroy` (schema defaults null in state)
- Apply was **not** used to "fix" the estate. The goal was a clean plan, then day-2 through code.

## Keywords

legacy, brownfield, proof, 70+ VMs, catalog from zero, VPC, networks, security groups, inventory, purpose map, vkcs, Nova, Cinder, Neutron, import, No changes, prevent_destroy
