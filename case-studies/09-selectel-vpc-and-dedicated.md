# Case study: Selectel VPC and dedicated Proxmox

**Context:** FinTech / SaaS platforms on a top-tier Russian cloud and datacenter operator  
**Timeline:** Ongoing across concurrent estates  
**Role:** Platform Engineer (end-to-end ownership)

## Challenge

One market (Selectel) exposed two APIs. Cloud servers needed OpenStack VPC (volume-boot, AZ, Cinder types). A second estate ran Kubernetes on dedicated hypervisors in the same provider's DCs. Console-built guests and colliding Proxmox names were a real apply risk. Hiring filters outside RU needed a clear class: OpenStack IaaS plus Proxmox VE, not a mystery local brand.

## Architecture

See diagram: [`diagrams/case-studies/09-selectel-vpc-and-dedicated.md`](../diagrams/case-studies/09-selectel-vpc-and-dedicated.md)

```text
Selectel (RU cloud + DC)
        │
        ├── Cloud / VPC  (OpenStack: Nova, Cinder, Neutron, Keystone)
        │     └── iac/terraform/openstack-selectel
        └── Dedicated HV (Proxmox VE, telmate)
              └── iac/terraform/selectel/proxmox-dc
                        │
                        ▼
              Kubernetes I operate + GitLab + data + CI
```

## What shipped

- VPC: Neutron nets, volume-boot kube masters (etcd disk), Postgres root/data/WAL, dual-homed GitLab, Selectel S3 remote state
- Dedicated: role-split kube pools (frontend, websocket, stateful, system, logging, isolated, test), Ceph OSDs, search, cron, analytics DB, VPN
- Unique-name discipline for `proxmox_vm_qemu` (provider does not reject colliding vmid/name)
- Same host path as other clouds: guests → cluster → CI/CD

## Results

- **Days to both APIs as code:** Selectel VPC (OpenStack) and dedicated Proxmox, not two console estates
- **Next stand in hours** once modules exist: same OpenStack / Proxmox habit, not a quarter of click-ops
- **Transfer:** international readers map VPC → OpenStack, dedicated → Proxmox VE. Live account IDs and WAN CIDRs stay out

## Stack and platforms

Terraform, Selectel Cloud (`selectel` + `openstack`), Proxmox VE (`telmate/proxmox`), Kubernetes, GitLab, PostgreSQL, Ceph, Selectel S3

**Note:** Selectel is not a legal rebrand of AWS or OVH. VPC maps to OpenStack. Dedicated maps to Proxmox on Selectel metal. See [`../iac/cloud/selectel.md`](../iac/cloud/selectel.md).

## Links

- Experience: [`../iac/cloud/selectel.md`](../iac/cloud/selectel.md)
- VPC root: [`../iac/terraform/openstack-selectel/`](../iac/terraform/openstack-selectel/)
- Dedicated root: [`../iac/terraform/selectel/proxmox-dc/`](../iac/terraform/selectel/proxmox-dc/)
- Coverage map: [`../iac/terraform/COVERAGE.md`](../iac/terraform/COVERAGE.md)
