# VMware Cloud Director (cloud.ru VMware / VCD)

**Business:** empty catalog to a working first-boot in days. Different API from Huawei-class Advanced. International VCD note below stays.

**Class:** VMware Cloud Director. Provider in samples: `vmware/vcd` `~> 3.14`.  
**Role:** Platform Engineer. **Proof** of greenfield on VCD: empty catalog maps → vApp → Ubuntu guest with extra disks and a working first-boot, written from zero.

**VMware note for international readers:** cloud.ru VMware is **VMware Cloud Director (VCD)**, not the Huawei-class Advanced API and not a vSphere HTML5 click-ops dump. Under the hood: org / VDC / Edge / org networks / vApp / VM / storage profiles. That work transfers to any VCD or vCloud Director estate (hosted or on-prem). Separate from [`cloud-ru-huawei.md`](cloud-ru-huawei.md) (AWS-shaped) and from [`proxmox.md`](proxmox.md).

## What I owned

- Tenant read-only **audit** first (catalogs, templates, Edge, IOPS), then a **deploy** stack
- Catalog maps: org network, storage policy, Ubuntu template (VM files use keys, not raw URNs)
- Linux VM from a shared Ubuntu-24.04 template: CPU/RAM, gold OS + data + WAL disks, MANUAL NIC
- Guest Customization + short initscript: users, random passwords, SSH keys, `PermitRootLogin no`, static netplan on POST
- Extra disks delayed until customization finishes (`allow_vm_reboot` otherwise leaves `ens*` DOWN)
- Least privilege: Terraform does **not** create or change Edge NAT / FW / IPsec / routes
- Same host then enters the [one-button CI](../ci/) path: Ansible, Vault, monitoring, inventory/docs (local LLM for confidential rewrite)

Published here: one DB-class guest. Private trees stay unpublished.

## Terraform in this lab

| Path | What |
|------|------|
| [`../terraform/vmware/`](../terraform/vmware/) | Sanitized root: catalog, guest init, `vm-database.tf`, `modules/vm_linux` |
| [`../terraform/vmware/audit/`](../terraform/vmware/audit/) | Read-only inventory |
| [`../ci/`](../ci/) | CI catalog: one-button story + [`../ci/pipelines/`](../ci/pipelines/) |

## Keywords

VMware, VCD, vCloud Director, cloud.ru VMware, Terraform, vApp, guest customization, initscript, cloud-init, netplan, IOPS, Ansible, Vault, EDR, CI/CD, GitLab CI
