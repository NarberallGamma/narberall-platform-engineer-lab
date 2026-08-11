# Stack: multi-env Terraform root

One root describes several environments with shared provider and remote state.  
Delivery shape on Huawei Cloud class (cloud.ru): network, ECS/compute, CCE/Kubernetes, RDS, OBS.  
AWS readers: map ECS→EC2, CCE→EKS-class, OBS→S3.

## Files

| File | Content |
|------|---------|
| `network_*.tf` | VPC / subnet slices |
| `ecs_*.tf` | GitLab, Vault raft, related VMs |
| `cce_*.tf` | Managed Kubernetes + node pools + AZ groups |
| `rds_*.tf` | PostgreSQL HA |
| `obs.tf` | Object storage buckets |
| `provider.tf` | Provider + S3-compatible backend |

## Navigation

- IaC hub: [`../../README.md`](../../README.md)
- Platforms: [`../../platforms/`](../../platforms/)
- Modules: [`../../modules/`](../../modules/)
