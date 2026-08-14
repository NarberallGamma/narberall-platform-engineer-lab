# Diagram: VMware VCD greenfield + CI stages

```mermaid
flowchart TB
  Audit[Read_only_VCD_audit] --> Catalog[Catalog_maps]
  Catalog --> VApp[vApp_plus_VM_from_template]
  VApp --> Guest[Guest_init_PRE_users_POST_net]
  Guest --> Disks[Extra_disks_after_delay]
  Disks --> CI[CI_stages]
  CI --> ANS[Ansible_bootstrap]
  CI --> Vault[Vault_creds]
  CI --> Mon[Monitoring_jobs]
  CI --> Docs[Inventory_and_diagrams]
  Docs --> LLM[Local_LLM_optional]
```

Case study: [`../../case-studies/06-vmware-vcd-greenfield.md`](../../case-studies/06-vmware-vcd-greenfield.md).  
Code: [`../../iac/terraform/vmware/`](../../iac/terraform/vmware/).  
CI: [`../../iac/ci/`](../../iac/ci/).
