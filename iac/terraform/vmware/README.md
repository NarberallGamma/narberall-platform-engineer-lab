# Platform: VMware Cloud Director (cloud.ru VMware / VCD)

**Class:** VMware Cloud Director. Provider: `vmware/vcd` `~> 3.14`.  
**Role:** greenfield from zero (empty VDC catalog → vApp → guest), not a vSphere click-ops dump.

cloud.ru sells this next to Huawei-class Advanced. Same company, different API. This folder is a **curated slice**: catalog maps, one DB-class Linux VM, guest customization, extra disks. Private org names, URNs, and CIDRs stay out.

Experience: [`../../cloud/vmware.md`](../../cloud/vmware.md)  
CI catalog (one-button, this stack as `TF_ROOT`): [`../../ci/`](../../ci/)  
Case study: [`../../../case-studies/06-vmware-vcd-greenfield.md`](../../../case-studies/06-vmware-vcd-greenfield.md)  
Map: [`../RESOURCES.md`](../RESOURCES.md)

```text
vmware/
  modules/vm_linux/     # vApp VM + extra disks + wait before reboot
  variables/            # catalog maps (network, storage, template)
  templates/            # VCD initscript (PRE users, POST netplan)
  files/ssh/            # example pubkeys only
  audit/                # read-only inventory (no create)
  artifacts/            # local secrets path; never commit passwords
```

| File | What |
|------|------|
| `catalog.tf` / `locals_catalog.tf` | Child module wired as `local.networks`, `local.storage` |
| `data.tf` | Existing VDC, routed org network, Edge, storage profile IOPS, Ubuntu template |
| `vapp.tf` / `vm-database.tf` | vApp + VM from catalog template (keys, not raw URNs in VM files) |
| `guest_init.tf` | Random 30-char passwords, SSH keys, 1500-char initscript check |
| `modules/vm_linux/` | `vcd_vapp_vm`, `time_sleep`, `vcd_vm_internal_disk` |
| `provider.tf.example` | `auth_type = api_token_file` + S3-compatible remote state |
| `audit/` | Catalogs, templates, Edge, VMs: plan/output only |

**Guest init (the part that usually breaks):** VCD runs the initscript twice (`precustomization` then `postcustomization`). Passwords and users on PRE. Static NIC + netplan only on POST. No `set -e` (a failed `chpasswd` otherwise aborts customization and `ens*` stays DOWN). Extra disks use `allow_vm_reboot`; wait `extra_disk_delay` (60s) after create or the reboot cuts POST. cloud.ru initscript cap: **1500** characters.

**Out of this slice (and out of the VCD role):** Edge NAT / FW / IPsec / routes. Those already exist; Terraform does not create or change them.

Copy `provider.tf.example` → `provider.tf`, `terraform.tfvars.example` → `terraform.tfvars`. Never commit tokens, state, or `artifacts/*/guest_secrets.json`.
