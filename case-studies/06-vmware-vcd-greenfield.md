# Case study: VMware VCD from zero + one-button host lifecycle

**Context:** Hosted VMware Cloud Director (cloud.ru VMware / VCD); empty Terraform, shared Ubuntu template  
**Timeline:** Greenfield stack in one delivery window  
**Role:** Platform Engineer (sole IaC owner for this VDC slice)

This is **proof** that VMware in this lab is real code, not a keyword. The VDC already had Edge and an org network. I did not click a guest together. I described catalog, vApp, disks, and first-boot in Terraform, then wired the same host into the usual CI stages.

## Challenge

A new VDC needed a Linux guest (DB-class: OS + data + WAL) with known SSH and a static NIC on first boot. The catalog template has no published password. Hosted VCD initscript is short (about **1500** characters). Extra disks reboot the VM. A naive script (`set -e`, netplan on PRE, disks too early) leaves the NIC DOWN and the console locked.

Rebuild was not the goal. A repeatable apply was.

## Architecture

See diagram: [`diagrams/case-studies/06-vmware-vcd-greenfield.md`](../diagrams/case-studies/06-vmware-vcd-greenfield.md)

```text
1) Audit stack (read-only): catalogs, template, Edge, storage IOPS
2) Catalog maps: network, storage policy, Ubuntu-24.04 template
3) vApp + VM from template (keys, not raw URNs)
4) Guest init: PRE users/passwords/SSH; POST ip link + netplan
5) Wait, then extra disks (data + WAL)
6) CI stages (manual or one pipeline):
   plan -> apply -> wait-ssh -> Ansible -> Vault -> monitoring -> docs
```

Honest scope: Edge NAT / FW / VPN stay outside Terraform (role has no Gateway Manage). PostgreSQL inside the guest is a later Ansible/app step, not this apply.

## What shipped

- Working `vmware/vcd` root: audit + deploy, remote state, service-account token file
- One DB-class Ubuntu 24.04 guest: 8 vCPU / 32 GB, three gold disks, MANUAL NIC
- Initscript under the length cap; `terraform check` on length and username charset
- Passwords random (30) to a local artifact (gitignore) and to state; not to git
- Public lab: sanitized module + one VM file + CI stage map. Private org/CIDR/URN unpublished

## Results

- First boot: SSH as `ubuntu` and extra admin, root SSH off, NIC up, default route in place
- Next guests are another `vm-*.tf` + the same CI jobs, not a new console ritual
- Docs/diagrams can be a pipeline stage (facts in; optional **local** LLM rewrite so nothing confidential leaves the network)

## Stack

Terraform, `vmware/vcd`, S3-compatible remote state, VCD Guest Customization, Ansible post-hook, Vault, host metrics, GitLab CI (staged)

**Note:** cloud.ru VMware is **VMware Cloud Director**. Different API from Huawei-class cloud.ru (`sbercloud`). Transferable VCD / vCloud Director experience.

## Links

- Sanitized code: [`iac/terraform/vmware/`](../iac/terraform/vmware/)
- Cloud page: [`iac/cloud/vmware.md`](../iac/cloud/vmware.md)
- CI catalog: [`iac/ci/`](../iac/ci/) (one-button + [`pipelines/`](../iac/ci/pipelines/))
- Related Huawei-class greenfield: [`02-cloud-platform-turnkey.md`](02-cloud-platform-turnkey.md)
- Related OpenStack-class legacy: [`05-legacy-estate-as-code.md`](05-legacy-estate-as-code.md)
