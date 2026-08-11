# Stack: multi-env Terraform root (current style)

One root describes several environments with shared provider and remote state.  
This is **current** delivery shape: network, ECS/compute, CCE/Kubernetes, RDS, OBS.

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
- Era index: [`../../eras/`](../../eras/)
- Modules: [`../../modules/`](../../modules/)
