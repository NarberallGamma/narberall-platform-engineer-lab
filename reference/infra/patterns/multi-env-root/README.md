# Pattern: multi-env Terraform root (current style)

One root describes several environments with shared provider and remote state. Shape mirrors current platform work: network, ECS/compute, CCE/Kubernetes, RDS, OBS.

## Files

| File | Content |
|------|---------|
| `network_*.tf` | VPC / subnet slices |
| `ecs_*.tf` | GitLab, Vault raft, related VMs |
| `cce_*.tf` | Managed Kubernetes + node pools + AZ extension groups |
| `rds_*.tf` | PostgreSQL HA |
| `obs.tf` | Object storage buckets |
| `provider.tf` | Provider + S3-compatible backend |

See also eras: [`../../eras/current-cloud-ru/`](../../eras/current-cloud-ru/).
