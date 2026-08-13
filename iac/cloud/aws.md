# AWS

**Role:** Platform Engineer on multi-account / multi-region platforms.

## What I owned

- VPC, subnets, IGW, NAT, routes, security groups, peering
- EC2, EBS, key pairs, GitLab-class app hosts
- RDS MySQL HA and EC2+EBS database patterns
- ElastiCache Redis replication groups
- EKS (and Karpenter-class node wiring) via Terragrunt live
- IAM roles, policies, CI users
- S3, bucket policy, CloudFront, ACM
- SNS, EventBridge, DLM snapshot ops
- Terragrunt live: account → region → env → shared|services → unit

Private source trees on this pattern had 200+ units. The lab shows one fake account, one region, shared networking/EKS, plus service units.

## Terraform in this lab

| Path | What |
|------|------|
| [`../terraform/aws/`](../terraform/aws/) | AWS IaC folder |
| [`../terraform/aws/root/`](../terraform/aws/root/) | Standalone root: VPC, EC2, RDS, ElastiCache, S3, CloudFront, IAM, observability |
| [`../terraform/aws/live/`](../terraform/aws/live/) | Terragrunt live (EKS, RDS, ElastiCache, Vault placeholder) |

Resource types: [`../terraform/RESOURCES.md`](../terraform/RESOURCES.md)

## Keywords

AWS, Terraform, Terragrunt, VPC, EC2, EKS, Karpenter, RDS, ElastiCache, IAM, S3, CloudFront, ACM, CI/CD, Kubernetes, observability
