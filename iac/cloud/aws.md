# AWS

**Business:** multi-account / multi-region as code so the next env is days, not a new project. Idle non-prod can follow the same night-park idea as Huawei-class. Existing owned-list below stays.

**Role:** Platform Engineer on multi-account / multi-region platforms.

## What I owned

- VPC, subnets, IGW, NAT, routes, security groups, cross-account / cross-region peering
- EC2 purpose hosts: GitLab, bastion, proxies, kube workers, backup (st1), Windows reports, graph pair
- Self-managed MySQL (primary/replica + binlogs) and analytics Postgres on io1
- RDS MySQL HA and EC2+EBS database patterns
- ElastiCache Redis replication groups
- EKS (and Karpenter-class node wiring) via Terragrunt live
- IAM roles, policies, CI users, export-job S3 IAM
- S3, CloudFront, ACM wildcards for `*.k8s.example.com`
- WAFv2 CloudFront allow-list (office / VPN docs CIDRs + public CDN ranges)
- SNS, EventBridge sensitive-API fan-in (IAM / S3 / EC2), DLM snapshots
- Terragrunt live: account → region → env → shared|services → unit
- One Terraform root per account + region (staging EU, prod AP, edge US-East, DWH US-East-2)

Private source trees on this pattern had 200+ units. The lab shows a standalone root, a curated multi-account slice, and Terragrunt live.

## Terraform in this lab

| Path | What |
|------|------|
| [`../terraform/aws/`](../terraform/aws/) | AWS IaC folder |
| [`../terraform/aws/root/`](../terraform/aws/root/) | Standalone root: VPC, EC2, RDS, ElastiCache, S3, CloudFront, IAM, observability |
| [`../terraform/aws/accounts/`](../terraform/aws/accounts/) | Multi-account roots: staging, prod, edge (ACM/WAF), DWH, EventBridge |
| [`../terraform/aws/live/`](../terraform/aws/live/) | Terragrunt live (EKS, RDS, ElastiCache, Vault placeholder) |

Resource types: [`../terraform/RESOURCES.md`](../terraform/RESOURCES.md)

Cluster Helm: [`../helm/`](../helm/).

## Keywords

AWS, Terraform, Terragrunt, VPC, EC2, EKS, Karpenter, RDS, ElastiCache, IAM, S3, CloudFront, ACM, CI/CD, Kubernetes, observability
