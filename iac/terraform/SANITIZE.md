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
- AWS multi-account: no real account IDs, VPC/SG/pcx IDs, office VPN lists, live WAF address dumps, or SSH public keys. Peering uses fake keys (`vpc-aaaa0001`). ACM hostnames stay on `example.com`
- Selectel: no account IDs, IAM tokens, live project UUIDs, HV FQDNs, or real WAN CIDRs. Public product hostnames (`cloud.api.selcloud.ru`, `s3.ru-1.storage.selcloud.ru`) and volume type names are allowed. Dedicated guests use `pve-sel-0N` and `10.20.22.0/24`
- Huawei compute catalog: fake UUIDs, documentation CIDRs (`10.10.x.x`), generic hostnames (`gitlab-dev-01`, `vault-prod-01`). No client project names, no live OBS bucket names, no AK/SK
- Cloudflare: documentation IPs only (`203.0.113.0/24`, `198.51.100.0/24`). No live zone IDs or account IDs
- Ansible payments identity (`iac/ansible/reference/ansible-payments-idplat/`): no PFX/PEM, no live `passwd.yaml`, no employer brand or AD DNS
- Ansible kits (`ansible-llm-collab`, `ansible-estate`, `ansible-app-platform`, `ansible-kb-linux`, `ansible-backup-borg`, `ansible-aws-hosts`): no EDR packages, no live PEM/PFX, no bootstrap credential dumps, no employer/client brands. Detail: [`../ansible/SANITIZE.md`](../ansible/SANITIZE.md)
- Helm kits: no kubeconfig, vault tokens, `secret-values.yaml`, or Argo repo secrets. Detail: [`../helm/SANITIZE.md`](../helm/SANITIZE.md)
- Workstation MCP/scripts (`practice/workstation/reference/`): no API tokens, no live Jira/wiki/GitLab URLs, no host SSH aliases or PEMs. Env files stay `chmod 600` on the machine (`env.example` only in git)
