# VMware

**Role:** Platform Engineer. VM estates, networking adjacency, guest Linux for platform services.

## What I owned

- VM layout and guest Linux for platform and app services
- Networking adjacency to the rest of the platform (load balancers, K8s nodes, data)
- Operating model: treat VMware as another compute substrate, then IaC and Kubernetes on top

Published Terraform in this lab uses Proxmox and OpenStack as the on-prem / private-cloud code proof. VMware client trees stay private.

## Related code

- Adjacent on-prem samples: [`../terraform/proxmox/`](../terraform/proxmox/), [`../terraform/openstack-selectel/`](../terraform/openstack-selectel/)
- Delivery story: [turnkey from zero](../../case-studies/02-cloud-platform-turnkey.md)

## Keywords

VMware, vSphere, Linux, Terraform, Kubernetes, on-prem, platform engineering
