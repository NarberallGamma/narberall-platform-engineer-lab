# Sanitize before publish (Ansible)

Same habit as [`../terraform/SANITIZE.md`](../terraform/SANITIZE.md). Kits under [`reference/`](reference/) are **full living trees** (roles, playbooks, templates, scripts, group_vars). Secrets stay out of git.

- Generic names: `platform`, `estate`, `admin`, `*.example.com`
- No employer / client brands, personal surnames, Windows paths, or dump paths
- CIDRs: documentation ranges only (`10.10.x.x`, `203.0.113.x`, `198.51.100.x`)
- Inventories: `hosts.ini.example` (live `hosts.ini` gitignored)
- Passwords: `passwd.yaml.example` / placeholder values only
- Never commit PEM/PFX, EDR packages, vault tokens, bootstrap credential dumps, or live `authorized_keys`
- Fake UUIDs `00000000-0000-4000-8000-...`
- Payments identity: no PFX/PEM, no live `passwd.yaml`, no employer brand or AD DNS
- Estate kits (`ansible-llm-collab`, `ansible-estate`, `ansible-app-platform`, `ansible-kb-linux`, `ansible-backup-borg`, `ansible-aws-hosts`): no EDR packages, no live PEM/PFX, no bootstrap credential dumps, no employer/client brands
- Existing kits stay: `ansible-bootstrap`, `ansible-edge`, `ansible-payments-idplat`, `monitoring-starter`, `ansible-runner`
