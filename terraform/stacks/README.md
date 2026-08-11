# Stacks (Terraform roots and Terragrunt live)

These are **delivery layouts**, not just libraries.

| Stack | Path | What you see |
|-------|------|----------------|
| Multi-env root | [`multi-env-root/`](multi-env-root/) | One TF root: network + ECS + CCE + RDS + OBS |
| Terragrunt live | [`terragrunt-live/`](terragrunt-live/) | `root.hcl` + `env-dev` units with dependencies |
| Multi-cloud notes | [`multi-cloud-notes/`](multi-cloud-notes/) | Short AWS/Selectel notes without client dumps |

Modules used by stacks live in [`../modules/`](../modules/).
