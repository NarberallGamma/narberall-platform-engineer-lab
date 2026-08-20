# Selectel

**Business:** one RU cloud/DC brand, two APIs, one owner: VPC in days, dedicated Proxmox without mixing the stories. International note below is unchanged.

**Role:** Platform Engineer. Two Selectel delivery modes: OpenStack VPC and dedicated Proxmox hypervisors in Selectel datacenters.

**Selectel note for international readers:** Selectel is one of the largest independent **Russian cloud and datacenter** operators. On the RU IaaS/colo market it is routinely grouped with Yandex Cloud, VK Cloud, and cloud.ru as a top-tier local provider (own DCs, cloud servers, object storage, dedicated, and colo). It is **not** a legal rebrand of AWS, OVH, or Rackspace.

Two products I used, two Terraform APIs:

1. **Selectel Cloud / VPC (OpenStack IaaS).** Under the hood: **Nova** compute, **Cinder** volumes (volume types like `fast.ru-3a` / `universal.ru-3b`), **Neutron** networks, **Keystone** identity (`cloud.api.selcloud.ru/identity/v3`). Providers: `selectel/selectel` + `terraform-provider-openstack/openstack`. Remote state often on Selectel S3 (`s3.ru-1.storage.selcloud.ru`). Transferable to any OpenStack IaaS (Selectel, NOVA Cloud KZ, other public OpenStack).
2. **Selectel dedicated / hosted hypervisors.** Bare-metal nodes in Selectel DCs running **Proxmox VE**. Provider: `telmate/proxmox`. Same market and facility, different API than VPC. Role-split Kubernetes node pools, Ceph, GitLab, VPN, search, and logging guests.

Different console and Terraform provider than Huawei-class cloud.ru (`sbercloud`) and than VK Cloud (`vkcs`). Same ownership sequence: access → network → compute/data → Kubernetes I operate → CI/CD.

## What I owned

- VPC: Neutron networks, volume-boot instances, AZ split (`ru-3a` / `ru-3b`), Postgres root/data/WAL, kube etcd data volumes
- Dedicated: Proxmox guests on Selectel HVs, pool-per-role kube nodes, Ceph OSDs, dual-NIC edge (LAN + WAN)
- Object storage for Terraform state
- Kubernetes on those guests (I install and operate)

## Terraform in this lab

| Path | Mode |
|------|------|
| [`../terraform/openstack-selectel/`](../terraform/openstack-selectel/) | Selectel Cloud / VPC (OpenStack) |
| [`../terraform/selectel/proxmox-dc/`](../terraform/selectel/proxmox-dc/) | Dedicated Proxmox on Selectel HVs |
| [`../terraform/selectel/`](../terraform/selectel/) | Hub: both modes |

Resource types: [`../terraform/RESOURCES.md`](../terraform/RESOURCES.md)  
Coverage vs other clouds: [`../terraform/COVERAGE.md`](../terraform/COVERAGE.md)

Cluster Helm: [`../helm/`](../helm/).

## Keywords

Selectel, Russian IaaS, datacenter, OpenStack, Nova, Cinder, Neutron, Keystone, selcloud, volume types, ru-3, Proxmox VE, dedicated, Terraform, Kubernetes, Ceph, GitLab, PostgreSQL
