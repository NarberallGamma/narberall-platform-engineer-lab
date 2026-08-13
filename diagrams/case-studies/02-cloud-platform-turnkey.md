# Diagram: Cloud platform turnkey

```mermaid
flowchart TB
  Mods[iac/terraform/modules]
  subgraph huawei [cloud-ru-huawei]
    MultiEnv[stacks/multi-env-root]
    TgLive[live]
  end
  subgraph awsfold [aws]
    Root[root]
    Live[live]
  end
  subgraph platform [Cloud platform]
    Net[Network]
    Vm[Compute]
    Data[Managed data]
    K8s[Kubernetes]
  end
  Mods --> MultiEnv
  Mods --> TgLive
  MultiEnv --> Net
  MultiEnv --> Data
  MultiEnv --> K8s
  TgLive --> Vm
  Root --> Net
  Live --> K8s
```

Case study: [`../../case-studies/02-cloud-platform-turnkey.md`](../../case-studies/02-cloud-platform-turnkey.md).  
Code: [`../../iac/terraform/`](../../iac/terraform/), [`../../iac/cloud/`](../../iac/cloud/).

