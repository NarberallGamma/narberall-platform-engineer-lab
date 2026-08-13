# Terraform modules (library)

Reusable modules for Huawei Cloud class / cloud.ru platforms (`sbercloud` provider).  
AWS-shaped building blocks (VPC, subnet, EIP, compute, security groups).  
Consumed by [`../cloud-ru-huawei/`](../cloud-ru-huawei/).

Experience: [`../../cloud/cloud-ru-huawei.md`](../../cloud/cloud-ru-huawei.md)

| Module | Purpose |
|--------|---------|
| [`vpc/`](vpc/) | VPC |
| [`subnet/`](subnet/) | Subnets (for_each map) |
| [`route/`](route/) | VPC route |
| [`route-table/`](route-table/) | Custom route table + routes |
| [`compute-instance/`](compute-instance/) | ECS instances (EC2-class) |
| [`eip/`](eip/) | Elastic IP |
| [`peering/`](peering/) | VPC peering |
| [`networking-vip/`](networking-vip/) | VIP + associate |
| [`security-group/`](security-group/) | Security group |
| [`security-group-rule/`](security-group-rule/) | SG rules |

IaC hub: [`../README.md`](../README.md)
