# Pattern: Terragrunt live (one env)

DRY layout: `root.hcl` generates provider + remote state; units under `env-dev/` depend on each other.

## Layout

```text
terragrunt-live/
  root.hcl
  _env/           # shared source pointers
  env-dev/
    env.hcl
    vpc/
    subnet/
    route/
```

## Why this shape

- Per-unit state keys (blast radius)
- Shared provider/backend generation
- `dependency` blocks for ordering (vpc → subnet → route)

Credentials and real bucket names are not in git. See `SANITIZE.md` at `reference/infra/`.
