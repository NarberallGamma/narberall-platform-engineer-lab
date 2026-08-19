# Hetzner

**Role:** Platform Engineer. Cloud VMs, networking, Linux baseline for application and CI hosts.

## What I owned

- Cloud VM estates and private networking
- Linux baseline (SSH, disk, bootstrap) for app and CI machines
- Path from empty project to running workloads without a large hyperscaler control plane

Published Terraform samples in this lab cover Huawei-class, AWS, Selectel, and Proxmox. Hetzner delivery used the same IaC and Linux operating model; no leftover client `.tf` tree to publish. See [`../terraform/COVERAGE.md`](../terraform/COVERAGE.md).

## Related code

- On-prem / VM adjacent samples: [`../terraform/proxmox/`](../terraform/proxmox/), [`../terraform/openstack-selectel/`](../terraform/openstack-selectel/)
- Delivery story: [turnkey from zero](../../case-studies/02-cloud-platform-turnkey.md)

## Keywords

Hetzner, Linux, Terraform, networking, CI/CD, bare-metal-adjacent, Kubernetes
