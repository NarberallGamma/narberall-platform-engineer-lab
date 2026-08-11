# Terraform modules

Reusable modules for cloud.ru-class networking and compute. Provider resource types use the public `sbercloud` provider.

| Module | Purpose |
|--------|---------|
| [`vpc/`](vpc/) | VPC |
| [`subnet/`](subnet/) | Subnets (for_each map) |
| [`route/`](route/) | VPC route |
| [`route-table/`](route-table/) | Custom route table + routes |
| [`compute-instance/`](compute-instance/) | ECS instances (map or count) |
| [`eip/`](eip/) | Elastic IP + optional associate |
| [`peering/`](peering/) | VPC peering connection |
| [`networking-vip/`](networking-vip/) | VIP + port association |
| [`security-group/`](security-group/) | Security group |
| [`security-group-rule/`](security-group-rule/) | Security group rules (for_each) |

Era map: [`../eras/README.md`](../eras/README.md)
