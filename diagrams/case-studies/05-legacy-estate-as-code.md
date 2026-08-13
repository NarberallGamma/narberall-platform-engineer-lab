# Diagram: Legacy estate as Terraform (VK Cloud / NOVA Cloud class)

```mermaid
flowchart TB
  Live[Hand_built_click_ops] --> RO[Read_only_API_inventory]
  RO --> Catalog[Catalog_from_zero]
  Catalog --> Nets[All_networks_subnets_SG]
  Catalog --> VMs[70plus_VMs_by_purpose]
  VMs --> Import[terraform_import]
  Import --> Plan[terraform_plan]
  Plan -->|No_changes| Managed[Managed_by_IaC]
```

Case study: [`../../case-studies/05-legacy-estate-as-code.md`](../../case-studies/05-legacy-estate-as-code.md).  
Code: [`../../iac/terraform/vkcloud/`](../../iac/terraform/vkcloud/).
