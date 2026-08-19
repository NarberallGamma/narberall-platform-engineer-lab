# Resources I describe as code

Curated samples only. Goal: show that an entire cloud platform (network → data → Kubernetes → edge → IAM) can be Terraform/Terragrunt.

**Why not full trees:** security and confidentiality (accounts, hostnames, real CIDRs, long-lived IAM), plus size. See [`SANITIZE.md`](SANITIZE.md).

Experience write-ups: [`../cloud/`](../cloud/).

## cloud.ru / Huawei Cloud (AWS-shaped)

| Area | Resource types (examples in repo) | Where |
|------|-----------------------------------|--------|
| Network | `sbercloud_vpc`, subnet, route, route table, EIP, peering, VIP, security group + rules | `modules/`, `cloud-ru-huawei/stacks/multi-env-root/` |
| Compute | `sbercloud_compute_instance`, server group | `cloud-ru-huawei/stacks/multi-env-root/ecs_*.tf` (platform + purpose: GitLab, Vault, runner, Redis, monitor) |
| Kubernetes | `sbercloud_cce_cluster`, `sbercloud_cce_node_pool` | `cloud-ru-huawei/stacks/multi-env-root/cce_*.tf` |
| Database | `sbercloud_rds_instance`, `sbercloud_rds_pg_account`, `sbercloud_rds_pg_database` | `rds_prod.tf`, `rds_databases.tf` |
| Messaging | `sbercloud_dms_kafka_instance`, topic, user | `dms_kafka.tf` |
| Object storage | `sbercloud_obs_bucket` | `obs.tf` |
| Terragrunt live | VPC, subnet, route, SG, compute units | `cloud-ru-huawei/live/` |
| Compute catalog | CCE x3, RDS PG x3, purpose ECS (GitLab, Vault, AppSec, Teleport, test), EVS, `do_not_import` | `cloud-ru-compute/deploy/` |
| Audit (read-only) | Same catalog maps, no `resource` | `cloud-ru-compute/audit/` |

## AWS

| Area | Resource types | Where |
|------|----------------|--------|
| Network | VPC module, IGW, routes, SG, NAT, EIP, peering | `aws/root/`, `aws/accounts/*/networking.tf` |
| Compute | `aws_instance`, EBS, volume attach, key pair | `aws/root/compute_*.tf`; `aws/accounts/` (GitLab, proxies, backup+st1, kube workers, Windows, graph) |
| Database | RDS MySQL; EC2 MySQL primary/replica + binlogs; analytics PG io1 1.3 TiB | `mysql_rds.tf`; `aws/accounts/*/mysql.tf`; `dwh-us-east-2/` |
| Cache | `aws_elasticache_replication_group` | `elasticache.tf`, `aws/live/` unit |
| Kubernetes | EKS (+ Karpenter unit placeholder) via Terragrunt; static kube workers | `aws/live/`; `aws/accounts/*/compute.tf` |
| IAM | roles, policies, users, attachments | `iam.tf`; `accounts/prod-ap-southeast-1/buckets.tf` |
| Storage / CDN | S3, CloudFront, ACM wildcards | `s3.tf`, `cloudfront_acm.tf`; `accounts/edge-us-east-1/acm.tf` |
| Edge | WAFv2 IP set + Web ACL (CloudFront scope) | `accounts/edge-us-east-1/waf.tf` |
| Ops | SNS, EventBridge sensitive-API fan-in, DLM snapshots | `observability.tf`; `accounts/modules/sensitive-events/` |

## Selectel (OpenStack VPC + dedicated Proxmox)

Selectel is a top-tier RU cloud/DC operator. VPC is OpenStack. Dedicated HVs run Proxmox. See [`../cloud/selectel.md`](../cloud/selectel.md) and [`COVERAGE.md`](COVERAGE.md).

| Area | Resource types | Where |
|------|----------------|--------|
| VPC network | Neutron network/subnet, external data, floating IP, SG | `openstack-selectel/network*.tf` |
| VPC compute | Image-boot + volume-boot instances, AZ `ru-3a`/`ru-3b`, server groups | `kube.tf`, `purpose.tf`, `volume_boot_kube.tf` |
| VPC storage | Cinder `fast.*` / `universal.*`, root/data/WAL, etcd disk | `postgres_ha.tf`, `volume_boot_kube.tf` |
| VPC edge | Dual-NIC GitLab | `gitlab_dualnic.tf` |
| Dedicated | `proxmox_vm_qemu` role-split kube pools, Ceph OSDs, VPN, GitLab | `selectel/proxmox-dc/` |

## VK Cloud / NOVA Cloud class (OpenStack IaaS)

NOVA Cloud class (Kazakhstan). Under the hood: OpenStack Nova / Cinder / Neutron / Keystone. Provider: `vk-cs/vkcs`.

| Area | Resource types | Where |
|------|----------------|--------|
| Catalog | networks, flavors, AZ, SG, volume types, key pairs as keys | `vkcloud/variables/` |
| Compute | `vkcs_compute_instance` (purpose-split `vm-*.tf` + module) | `vkcloud/vm-*.tf`, `modules/compute_instance/`, `live/sec-monitor/` |
| Storage | `vkcs_blockstorage_volume`, `vkcs_compute_volume_attach` | same files |
| Brownfield | `prevent_destroy`, short `ignore_changes`, import runbook | `vkcloud/brownfield.tf`, `IMPORT.md`, `ESTATE.md` |

## VMware Cloud Director (VCD)

Hosted VCD (cloud.ru VMware). Provider: `vmware/vcd`. Guest init + extra-disk delay. Documentation CIDRs only.

| Area | Resource types | Where |
|------|----------------|--------|
| Catalog | org network, storage policy, Ubuntu template as keys | `vmware/variables/` |
| Compute | `vcd_vapp`, `vcd_vapp_vm`, `vcd_vapp_org_network` | `vmware/vapp.tf`, `vm-database.tf` |
| Storage | `vcd_vm_internal_disk`, storage profile IOPS | `vmware/modules/vm_linux/` |
| Guest | customization.initscript, random passwords, SSH | `vmware/guest_init.tf`, `templates/guest_init.sh.tftpl` |
| Audit | catalogs, Edge, network, IOPS (read-only) | `vmware/audit/` |

## Proxmox

| Area | Resource types | Where |
|------|----------------|--------|
| Guests | `proxmox_vm_qemu` masters/workers/GitLab/Postgres/runners/Vault/monitor | `proxmox/` |
| Selectel DC | Role-split kube, Ceph, search, dual-NIC VPN/GitLab | `selectel/proxmox-dc/` |

## Cloudflare

| Area | Resource types | Where |
|------|----------------|--------|
| DNS | 3 zones, A/CNAME/MX/TXT/CAA | `cloudflare/zones.tf`, `records_*.tf` |
| Edge | page rules, zone settings | `cloudflare/page_rules.tf` |
| Access | Zero Trust apps + policies | `cloudflare/access.tf` |

## Layout styles

| Style | Path |
|-------|------|
| Multi-env single root | `cloud-ru-huawei/stacks/multi-env-root/` |
| Terragrunt DRY (Huawei-class) | `cloud-ru-huawei/live/` |
| Terragrunt live (AWS account/region/env) | `aws/live/` |
| Standalone AWS root | `aws/root/` |
| Multi-account AWS roots (staging / prod / edge / DWH) | `aws/accounts/` |
| Selectel Cloud (OpenStack VPC) | `openstack-selectel/` |
| Selectel dedicated Proxmox | `selectel/proxmox-dc/` |
| Brownfield catalog + purpose VMs (vkcs) | `vkcloud/` |
| Huawei compute catalog (split state, CCE/RDS/ECS) | `cloud-ru-compute/` |
| VCD greenfield (vapp + guest init) | `vmware/` |
