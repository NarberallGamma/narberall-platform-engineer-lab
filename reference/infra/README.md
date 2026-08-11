# Infrastructure as Code (Terraform)

How I work with Terraform on real platforms: greenfield adoption, reusable modules, Terragrunt live layouts, and brownfield import until `plan` is clean.

## Map

| Path | What |
|------|------|
| [`modules/`](modules/) | Reusable building blocks (VPC, subnet, route, compute, EIP, peering) |
| [`patterns/multi-env-root/`](patterns/multi-env-root/) | One root managing several environments |
| [`patterns/terragrunt-live/`](patterns/terragrunt-live/) | Terragrunt DRY layout (one sample env) |
| [`patterns/multi-cloud-notes/`](patterns/multi-cloud-notes/) | Notes on AWS / Selectel-class workflows |
| [`examples/greenfield-platform/`](examples/greenfield-platform/) | Minimal compose of modules |
| [`examples/brownfield-import/`](examples/brownfield-import/) | Import checklist with fake resource IDs |
| [`SANITIZE.md`](SANITIZE.md) | Rules before publishing any snippet |

## Keywords

Terraform, Terragrunt, IaC, modules, multi-env, brownfield import, remote state (S3/OBS-compatible), cloud platform, network, compute

## Case studies

- [Cloud platform turnkey (greenfield)](../../case-studies/02-cloud-platform-turnkey.md)
- [Brownfield import into Terraform state](../../case-studies/04-terraform-brownfield-import.md)

## Related placeholders

- [`terraform-ai-stack/`](terraform-ai-stack/)  -  AI-oriented baseline (evolving)
- [`monitoring-starter/`](monitoring-starter/)  -  observability starter
- [`ansible-bootstrap/`](ansible-bootstrap/)  -  host baseline
