# Sanitize before publish

This lab publishes **curated slices**, not full production Terraform trees (security, confidentiality, and repo size / multi-year history).

- Use generic names: `project-a`, `env-dev`, `fintech-platform`
- No client legal names, tenant IDs, real hostnames, or internal domains
- CIDRs: documentation ranges only (for example `10.10.0.0/16`)
- Configs: `*.tfvars.example` only
- Never commit state, `.terraform/`, private keys, or lock files from production
- Import examples use fake IDs (`vpc-aaaa`, `subnet-bbbb`)
- VCD: no real org / VDC / Edge names, URNs, MACs, or `token.json` refresh tokens
- Guest secrets and live initscripts stay under `artifacts/` (not committed)
- Prefer representative resources over copying entire account/region trees
- Huawei compute catalog: fake UUIDs, documentation CIDRs (`10.10.x.x`), generic hostnames (`gitlab-dev-01`, `vault-prod-01`). No client project names, no live OBS bucket names, no AK/SK
- Cloudflare: documentation IPs only (`203.0.113.0/24`, `198.51.100.0/24`). No live zone IDs or account IDs
- Ansible payments identity: no PFX/PEM, no live `passwd.yaml`, no employer brand or AD DNS
