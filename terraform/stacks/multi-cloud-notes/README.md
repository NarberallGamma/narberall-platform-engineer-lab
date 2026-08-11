# Multi-cloud and on-prem experience

Published `.tf` trees focus on **cloud.ru/Huawei (AWS-shaped)**, **AWS**, and **OpenStack/Selectel**.  
The same ownership model applied on other platforms in previous roles. Full private trees stay out of git (NDA / ownership).

## Platforms operated

| Platform | What I owned |
|----------|----------------|
| **AWS** | VPC, EC2, EIP/EBS, RDS-class DB, S3 state; see [`../../platforms/aws/`](../../platforms/aws/) |
| **cloud.ru / Huawei Cloud** | IAM/project baseline through CCE Kubernetes, RDS, OBS; AWS-analogue skills; see [`../../platforms/cloud-ru-huawei/`](../../platforms/cloud-ru-huawei/) |
| **Google Cloud** | Project/network bootstrap, compute, and delivery into GKE-class / VM workloads |
| **Hetzner** | Cloud VMs, networking, Linux baseline for app and CI hosts |
| **VMware** | VM estates, networking adjacency, guest Linux for platform services |
| **Proxmox** | Hypervisor clusters, guests, storage-aware layouts for labs and production-like stands |
| **Bare metal** | Rack/server Linux, bootstrap, and Kubernetes / app platforms without a hyperscaler |

## Greenfield pattern (every cloud)

Empty project or empty hardware → IAM/access → VPC/network → compute/data → **Kubernetes I install and run** → CI/CD + apps + monitoring.

## Tooling

Terraform / OpenTofu, Terragrunt, remote state, `tfswitch` / lock files when multiple providers coexist.
