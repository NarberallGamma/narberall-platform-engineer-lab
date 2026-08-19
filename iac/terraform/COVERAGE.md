# Terraform coverage (published vs private)

Curated slices only. Goal: one glance that the same engineer shipped IaC on several clouds, without dumping client trees.

| Platform | Published in this lab | Private source shape (not copied) | Foreign-reader class |
|----------|----------------------|-----------------------------------|----------------------|
| AWS | `aws/root`, `aws/accounts`, `aws/live` | Multi-account / multi-region roots + large Terragrunt live | AWS |
| cloud.ru / Huawei | `cloud-ru-huawei`, `cloud-ru-compute` | Multi-env root + compute catalog | Huawei Cloud class, AWS-shaped |
| VK Cloud | `vkcloud` | 70+ brownfield VMs, catalog, import | NOVA Cloud class, OpenStack |
| VMware | `vmware` | VCD greenfield + audit | VCD / vCloud Director |
| Selectel Cloud | `openstack-selectel` | OpenStack VPC, volume-boot, AZ, S3 state | OpenStack IaaS, top-tier RU cloud |
| Selectel dedicated | `selectel/proxmox-dc` | Proxmox on Selectel HVs, role-split kube, Ceph | Proxmox VE in Selectel DCs |
| Proxmox (other DCs) | `proxmox` | Additional VE estates | Proxmox VE |
| Cloudflare | `cloudflare` | Multi-zone DNS + Access | Cloudflare |
| Google Cloud | experience page only | No leftover client `.tf` tree to publish | GCP / GKE-class |
| Hetzner | experience page only | No leftover client `.tf` tree to publish | Hetzner Cloud |
| Bare metal | experience page only | Rack/Linux narrative | Linux on metal |

Nothing material is sitting unpublished in the remaining client Terraform folders except full-size dumps (hundreds of generated AWS files, live Terragrunt caches, tokens). Those stay private by design. See [`SANITIZE.md`](SANITIZE.md).
