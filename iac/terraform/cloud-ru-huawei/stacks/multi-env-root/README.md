# Stack: multi-env Terraform root

One root describes several environments with shared provider and remote state.  
Huawei Cloud class (cloud.ru): network, ECS/compute, CCE/Kubernetes, RDS (+ DBs), DMS Kafka, OBS.

AWS readers: ECS→EC2, CCE→EKS-class, OBS→S3, DMS→MSK-class.

## Files

| File | Content |
|------|---------|
| `network_*.tf` | VPC / subnet slices |
| `network_peering_sg.tf` | Peering, SG modules, NAT EIP |
| `ecs_*.tf` / `ecs_platform.tf` | GitLab, Vault, LB/WAF, Teleport, app VMs |
| `cce_*.tf` | Managed Kubernetes + node pools |
| `rds_prod.tf` / `rds_databases.tf` | PostgreSQL HA + logical DBs/users |
| `dms_kafka.tf` | Kafka instance, topics, users |
| `obs.tf` | Object storage buckets |
| `provider.tf` | Provider + S3-compatible backend |

Experience: [`../../../../cloud/cloud-ru-huawei.md`](../../../../cloud/cloud-ru-huawei.md)  
Full resource map: [`../../../RESOURCES.md`](../../../RESOURCES.md)
