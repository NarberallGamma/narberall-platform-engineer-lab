# OpenStack / Selectel Cloud (VPC)

**Business:** volume-boot VPC in days (AZ, WAL, etcd disk). Dedicated Proxmox is a sibling story, not this page. Existing VPC note below stays.

**Role:** Platform Engineer. Selectel Cloud VPC: OpenStack networking and volume-boot guests for Kubernetes, GitLab, and Postgres.

This page is the **VPC** slice. Selectel as a market and the dedicated/Proxmox mode: [`selectel.md`](selectel.md).

**Selectel note for international readers:** Selectel Cloud (VPC) is **OpenStack IaaS**. Under the hood: Nova, Cinder, Neutron, Keystone. Auth: `cloud.api.selcloud.ru/identity/v3`. Volume types are AZ-scoped (`fast.ru-3a`, `universal.ru-3b`). That work is transferable OpenStack experience (Selectel, NOVA Cloud KZ, other public OpenStack). Provider pair in this lab: `selectel/selectel` + `terraform-provider-openstack/openstack`.

## What I owned

- Networks, subnets, floating IPs, security groups
- Volume-boot instances across AZs, Cinder volume types
- Postgres HA: root / data / WAL disks, anti-affinity
- Kube control-plane extra disk for etcd and certs
- Dual-homed GitLab (external + VPC)
- Kubernetes platform on those guests (I install and operate)

## Terraform in this lab

| Path | What |
|------|------|
| [`../terraform/openstack-selectel/`](../terraform/openstack-selectel/) | Selectel Cloud / VPC root |
| [`../terraform/selectel/proxmox-dc/`](../terraform/selectel/proxmox-dc/) | Dedicated Proxmox on Selectel HVs |

Resource types: [`../terraform/RESOURCES.md`](../terraform/RESOURCES.md)

Cluster Helm: [`../helm/`](../helm/).

## Keywords

OpenStack, Selectel, Selectel Cloud, Nova, Cinder, Neutron, Keystone, Terraform, Kubernetes, GitLab, PostgreSQL, volume-boot, ru-3
