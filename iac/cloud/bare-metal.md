# Bare metal

**Role:** Platform Engineer. Rack/server Linux, bootstrap, Kubernetes and app platforms without a hyperscaler.

## What I owned

- Server Linux from empty hardware: disks, network, bootstrap
- Hands-on assembly of PCs and **simple office servers** (small-office, not a datacenter integrator claim); BIOS/UEFI and hardware diagnosis before the OS is blamed — same loop as [`../../practice/home-lab/os-workstation.md`](../../practice/home-lab/os-workstation.md)
- Kubernetes I install and run on the metal (or on VMs I placed there)
- CI/CD, apps, and monitoring with the same ownership as in public cloud

This is the same turnkey sequence as AWS or Huawei-class, minus the managed control plane. Client rack inventories stay private.

## Related code

- Guest/K8s samples: [`../terraform/proxmox/`](../terraform/proxmox/), [`../terraform/openstack-selectel/`](../terraform/openstack-selectel/)
- Delivery story: [turnkey from zero](../../case-studies/02-cloud-platform-turnkey.md)

## Keywords

Bare metal, Linux, Kubernetes, Terraform, Ansible, CI/CD, on-prem
