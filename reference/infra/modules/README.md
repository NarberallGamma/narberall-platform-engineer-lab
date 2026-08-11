# Terraform modules

Reusable modules for cloud.ru-class networking and compute. Names are generic; provider resource types use the public `sbercloud` provider.

| Module | Purpose |
|--------|---------|
| [`vpc/`](vpc/) | VPC |
| [`subnet/`](subnet/) | Subnets (for_each map) |
| [`route/`](route/) | VPC route |
| [`compute-instance/`](compute-instance/) | ECS instances (map or count) |
| [`eip/`](eip/) | Elastic IP + optional associate |
| [`peering/`](peering/) | VPC peering connection |

Compose via [`../examples/greenfield-platform/`](../examples/greenfield-platform/).
