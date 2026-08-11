# Case study: Brownfield import into Terraform state

**Context:** Existing cloud estate built mostly by hand; need IaC without rebuild  
**Timeline:** Multi-week import and reconciliation window  
**Role:** Platform Engineer (sole IaC owner)

## Challenge

Production and adjacent stands already existed (VPC, compute, managed DB, Kubernetes clusters, object storage). Rewriting from scratch was not an option. Goal: bring live resources under Terraform state, align code with reality, and reach a clean `terraform plan` (no unexpected destroy/create).

## Architecture

See diagram: [`diagrams/case-studies/04-terraform-brownfield-import.md`](../diagrams/case-studies/04-terraform-brownfield-import.md)

```text
1) Audit / inventory (read-only discovery of live resources)
2) Write matching Terraform resource blocks (generic names in public examples)
3) terraform import (or equivalent) per resource address
4) terraform plan -refresh-only / plan until No changes
5) Day-2: manage drift via code, not console
```

## What shipped

- Infra: Terraform root covering multi-env resources already running in cloud
- Process: inventory → code → import → reconcile provider quirks → clean plan
- Docs: operator notes for backend credentials, provider mirror, safe refresh-only
- Guardrails: temporary disable of broken provider resources instead of risky destroy

## Results

- Hand-built estate represented in state without recreating production
- `terraform plan` converged to no unintended changes
- Team gained a single source of truth for further changes (scale, replace, add)

## Stack

Terraform, S3-compatible remote state, cloud.ru-class provider, import workflow, audit/inventory pattern

## Links

- Import example (fake IDs): [`terraform/examples/brownfield-import/`](../terraform/examples/brownfield-import/)
- Multi-env root pattern: [`terraform/stacks/multi-env-root/`](../terraform/stacks/multi-env-root/)
- Related greenfield story: [`02-cloud-platform-turnkey.md`](02-cloud-platform-turnkey.md)
