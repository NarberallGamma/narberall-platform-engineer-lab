# Diagram: Brownfield import

```mermaid
flowchart LR
  Live[Hand_built_cloud] --> Audit[Audit_inventory]
  Audit --> Code[Terraform_code]
  Code --> Import[terraform_import]
  Import --> Plan[terraform_plan]
  Plan -->|drift| Code
  Plan -->|clean| Managed[Managed_by_IaC]
```

Case study: [`../../case-studies/04-terraform-brownfield-import.md`](../../case-studies/04-terraform-brownfield-import.md).  
Code: [`../../iac/terraform/examples/brownfield-import/`](../../iac/terraform/examples/brownfield-import/).

