# Multi-cloud and on-prem experience

## Published code proof in this repo

| Platform | Where |
|----------|--------|
| cloud.ru / Huawei (AWS-shaped) | [`../../platforms/cloud-ru-huawei/`](../../platforms/cloud-ru-huawei/), stacks/modules |
| AWS (roots + Terragrunt) | [`../../platforms/aws/`](../../platforms/aws/), [`../aws-terragrunt-live/`](../aws-terragrunt-live/) |
| OpenStack / Selectel | [`../../platforms/openstack-selectel/`](../../platforms/openstack-selectel/) |
| Proxmox | [`../../platforms/proxmox/`](../../platforms/proxmox/) |
| Cloudflare DNS | [`../../platforms/cloudflare/`](../../platforms/cloudflare/) |

## Also operated (narrative / other private trees)

| Platform | What I owned |
|----------|----------------|
| Google Cloud | Project/network bootstrap, compute, delivery into GKE-class / VM workloads |
| Hetzner | Cloud VMs, networking, Linux baseline for app and CI hosts |
| VMware | VM estates, networking adjacency, guest Linux for platform services |
| Bare metal | Rack/server Linux, bootstrap, Kubernetes / app platforms without a hyperscaler |

## Greenfield pattern

Empty project or empty hardware → IAM/access → VPC/network → compute/data → Kubernetes I install and run → CI/CD + apps + monitoring.
