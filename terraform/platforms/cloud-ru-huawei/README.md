# Platform: cloud.ru / Huawei Cloud (AWS-shaped)

Production-style Terraform for Huawei Cloud class environments (cloud.ru and peers).  
Resource model maps to AWS (VPC, compute, managed Kubernetes, RDS, S3-compatible object storage).

## Where the code is

| What | Path |
|------|------|
| Multi-env root (ECS, CCE, RDS, OBS, network) | [`../../stacks/multi-env-root/`](../../stacks/multi-env-root/) |
| Terragrunt live sample | [`../../stacks/terragrunt-live/`](../../stacks/terragrunt-live/) |
| Reusable modules | [`../../modules/`](../../modules/) |
| Greenfield example | [`../../examples/greenfield-platform/`](../../examples/greenfield-platform/) |
| Brownfield import checklist | [`../../examples/brownfield-import/`](../../examples/brownfield-import/) |

```mermaid
flowchart LR
  Modules[modules] --> MultiEnv[stacks/multi-env-root]
  Modules --> Tg[stacks/terragrunt-live]
  MultiEnv --> Cloud[Huawei-class cloud]
  Tg --> Cloud
```
