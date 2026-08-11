# Pattern: multi-env Terraform root

One root module describes several environments (here: `dev` and `prod` network slices) with a shared provider and remote state.

## When to use

- Single team owns all stands
- Prefer fewer state files than Terragrunt-per-unit
- Brownfield import of an existing estate into one (or few) roots

## Related

- Case study: brownfield import
- Modules for reuse: `../../modules/`
