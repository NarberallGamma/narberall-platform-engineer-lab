# Sanitize before publish

- Use generic names: `project-a`, `env-dev`, `fintech-platform`
- No client legal names, tenant IDs, real hostnames, or internal domains
- CIDRs: documentation ranges only (for example `10.10.0.0/16`)
- Configs: `*.tfvars.example` only
- Never commit state, `.terraform/`, private keys, or lock files from production
- Import examples use fake IDs (`vpc-aaaa`, `subnet-bbbb`)
