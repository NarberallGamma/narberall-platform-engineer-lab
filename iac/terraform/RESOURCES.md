# Resources I describe as code

Curated samples only. Goal: show that an entire cloud platform (network → data → Kubernetes → edge → IAM) can be Terraform/Terragrunt.

**Why not full trees:** security and confidentiality (accounts, hostnames, real CIDRs, long-lived IAM), plus size. See [`SANITIZE.md`](SANITIZE.md).

Experience write-ups: [`../cloud/`](../cloud/).

## cloud.ru / Huawei Cloud (AWS-shaped)

| Area | Resource types (examples in repo) | Where |
|------|-----------------------------------|--------|
| Network | `sbercloud_vpc`, subnet, route, route table, EIP, peering, VIP, security group + rules | `modules/`, `cloud-ru-huawei/stacks/multi-env-root/` |
| Compute | `sbercloud_compute_instance`, server group | `cloud-ru-huawei/stacks/multi-env-root/ecs_*.tf` |
| Kubernetes | `sbercloud_cce_cluster`, `sbercloud_cce_node_pool` | `cloud-ru-huawei/stacks/multi-env-root/cce_*.tf` |
| Database | `sbercloud_rds_instance`, `sbercloud_rds_pg_account`, `sbercloud_rds_pg_database` | `rds_prod.tf`, `rds_databases.tf` |
| Messaging | `sbercloud_dms_kafka_instance`, topic, user | `dms_kafka.tf` |
| Object storage | `sbercloud_obs_bucket` | `obs.tf` |
| Terragrunt live | VPC, subnet, route, SG, compute units | `cloud-ru-huawei/live/` |

## AWS

| Area | Resource types | Where |
|------|----------------|--------|
| Network | VPC module, IGW, routes, SG, NAT, EIP, peering | `aws/root/` |
| Compute | `aws_instance`, EBS, volume attach, key pair | `aws/root/` |
| Database | `aws_db_instance` (RDS MySQL), EC2+EBS DB pattern | `mysql_rds.tf`, `aws/root/modules/db_instance/` |
| Cache | `aws_elasticache_replication_group` | `elasticache.tf`, `aws/live/` unit |
| Kubernetes | EKS (+ Karpenter unit placeholder) via Terragrunt | `aws/live/` |
| IAM | roles, policies, users, attachments | `iam.tf` |
| Storage / CDN | S3, bucket policy, CloudFront, ACM | `s3.tf`, `cloudfront_acm.tf` |
| Ops | SNS, EventBridge, DLM snapshots | `observability.tf` |

## OpenStack / Selectel

| Area | Resource types | Where |
|------|----------------|--------|
| Network | network, subnet, floating IP, security group + rule | `openstack-selectel/` |
| Compute | instances (bastion, kube, GitLab, Postgres), server group | `kube.tf` |
| Storage | block volumes + attach | `volumes_sg.tf` |

## Proxmox

| Area | Resource types | Where |
|------|----------------|--------|
| Guests | `proxmox_vm_qemu` masters/workers/GitLab/Postgres | `proxmox/` |

## Cloudflare

| Area | Resource types | Where |
|------|----------------|--------|
| DNS | zone, records | `cloudflare/` |

## Layout styles

| Style | Path |
|-------|------|
| Multi-env single root | `cloud-ru-huawei/stacks/multi-env-root/` |
| Terragrunt DRY (Huawei-class) | `cloud-ru-huawei/live/` |
| Terragrunt live (AWS account/region/env) | `aws/live/` |
| Standalone AWS root | `aws/root/` |
