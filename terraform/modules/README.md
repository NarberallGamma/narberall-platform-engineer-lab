# Terraform modules (library)

Reusable modules for cloud.ru-class platforms (`sbercloud` provider).  
They are **consumed by stacks** under [`../stacks/`](../stacks/). Start there if you want full delivery layout.

| Module | Purpose |
|--------|---------|
| [`vpc/`](vpc/) | VPC |
| [`subnet/`](subnet/) | Subnets (for_each map) |
| [`route/`](route/) | VPC route |
| [`route-table/`](route-table/) | Custom route table + routes |
| [`compute-instance/`](compute-instance/) | ECS instances |
| [`eip/`](eip/) | Elastic IP |
| [`peering/`](peering/) | VPC peering |
| [`networking-vip/`](networking-vip/) | VIP + associate |
| [`security-group/`](security-group/) | Security group |
| [`security-group-rule/`](security-group-rule/) | SG rules |

IaC hub: [`../README.md`](../README.md)
