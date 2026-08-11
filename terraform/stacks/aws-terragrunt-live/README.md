# Stack: AWS Terragrunt live (sanitized)

Layout used on large AWS platforms: **account → region → env → shared|services → unit**.

Private source trees had 200+ units (EKS, Karpenter, RDS, ElastiCache, Vault, IAM).  
Here: one fake account, one region, shared networking/EKS plus two service units.

Companion to Huawei/cloud.ru Terragrunt under [`../terragrunt-live/`](../terragrunt-live/).
