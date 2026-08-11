# Resources I describe as code

Curated samples only.  
Goal: show that an entire cloud platform (network → data → Kubernetes → edge → IAM) can be Terraform/Terragrunt.

**Why not full trees:** security and confidentiality (accounts, hostnames, real CIDRs, long-lived IAM), plus size. Private IaC repos often carry multi-year history; publishing them whole would hide the signal. See also [`SANITIZE.md`](SANITIZE.md) and the root README.

## cloud.ru / Huawei Cloud (AWS-shaped)

| Area | Resource types (examples in repo) | Where |
|------|-----------------------------------|--------|
| Network | `sbercloud_vpc`, subnet, route, route table, EIP, peering, VIP, security group + rules | `modules/`, `stacks/multi-env-root/` |
| Compute | `sbercloud_compute_instance`, server group | `stacks/multi-env-root/ecs_*.tf`, `ecs_platform.tf` |
| Kubernetes | `sbercloud_cce_cluster`, `sbercloud_cce_node_pool` | `stacks/multi-env-root/cce_*.tf` |
| Database | `sbercloud_rds_instance`, `sbercloud_rds_pg_account`, `sbercloud_rds_pg_database` | `rds_prod.tf`, `rds_databases.tf` |
| Messaging | `sbercloud_dms_kafka_instance`, topic, user | `dms_kafka.tf` |
| Object storage | `sbercloud_obs_bucket` | `obs.tf` |

## AWS

| Area | Resource types | Where |
|------|----------------|--------|
| Network | VPC module, IGW, routes, SG, NAT, EIP, peering | `platforms/aws/` |
| Compute | `aws_instance`, EBS, volume attach, key pair | `platforms/aws/` |
| Database | `aws_db_instance` (RDS MySQL), EC2+EBS DB pattern | `mysql_rds.tf`, `modules/db_instance/` |
| Cache | `aws_elasticache_replication_group` | `elasticache.tf`, Terragrunt unit |
| Kubernetes | EKS (+ Karpenter unit placeholder) via Terragrunt | `stacks/aws-terragrunt-live/` |
| IAM | roles, policies, users, attachments | `iam.tf` |
| Storage / CDN | S3, bucket policy, CloudFront, ACM | `s3.tf`, `cloudfront_acm.tf` |
| Ops | SNS, EventBridge, DLM snapshots | `observability.tf` |

## OpenStack / Selectel

| Area | Resource types | Where |
|------|----------------|--------|
| Network | network, subnet, floating IP, security group + rule | `platforms/openstack-selectel/` |
| Compute | instances (bastion, kube, GitLab, Postgres), server group | `kube.tf` |
| Storage | block volumes + attach | `volumes_sg.tf` |

## Proxmox

| Area | Resource types | Where |
|------|----------------|--------|
| Guests | `proxmox_vm_qemu` masters/workers/GitLab/Postgres | `platforms/proxmox/` |

## Cloudflare

| Area | Resource types | Where |
|------|----------------|--------|
| DNS | zone, records | `platforms/cloudflare/` |

## Layout styles

| Style | Path |
|-------|------|
| Multi-env single root | `stacks/multi-env-root/` |
| Terragrunt DRY (Huawei-class) | `stacks/terragrunt-live/` |
| Terragrunt live (AWS account/region/env) | `stacks/aws-terragrunt-live/` |
