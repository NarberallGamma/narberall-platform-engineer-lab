# Diagram: Huawei-class compute catalog

```mermaid
flowchart TB
  subgraph live [Sibling Terragrunt live]
    VPC[VPC subnet route peering]
    NGFW[NGFW EIP VIP]
  end
  subgraph bucket [OBS-class state bucket]
    LiveKey["live/env/unit"]
    DeployKey["platform/deploy"]
    AuditKey["platform/audit"]
  end
  subgraph compute [This Terraform root]
    Cat[Catalog maps]
    CCE[CCE x3]
    RDS[RDS PG x3]
    ECS[GitLab Vault AppSec test]
    TP[Teleport new VM]
    Audit[Audit outputs]
  end
  live --> Cat
  Cat --> CCE
  Cat --> RDS
  Cat --> ECS
  Cat --> TP
  Cat --> Audit
  LiveKey --> live
  DeployKey --> compute
  AuditKey --> Audit
```

Case study: [`../../case-studies/07-huawei-compute-catalog.md`](../../case-studies/07-huawei-compute-catalog.md).  
Host continuation: [`../../case-studies/10-ansible-estate.md`](../../case-studies/10-ansible-estate.md).  
Cluster continuation: [`../../case-studies/11-helm-estate.md`](../../case-studies/11-helm-estate.md).

No real IPs or client hostnames in labels.
