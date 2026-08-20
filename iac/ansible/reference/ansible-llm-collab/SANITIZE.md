# Sanitize notes (this tree)

What was removed or rewritten before publish:

- Employer / client brand strings and AD DNS
- Inventory hostnames and live IPs (doc ranges only)
- Personal admin account names
- Live SSH public keys (replaced with CHANGE_ME placeholders)
- EDR vendor package name and install paths
- Encrypted SOPS blob for the metrics stack (placeholder `secrets.sops.yml.example`)
- `artifacts/` (EDR debs, bootstrap credentials, logs)

What stayed (on purpose):

- Full role graphs, Jinja, run wrappers, Nextcloud matrices, n8n workflow JSON
- Vendored `ansible-lockdown.ubuntu24_cis` (third-party CIS text, including "lockdown")
- Russian operator comments inside roles (original automation language)
- Product names: Docker, Nextcloud, Kafka, n8n, CIS, Ubuntu, NVIDIA, GitLab, nginx

Do not add real certificates, Vault tokens, EDR packages, or live `hosts.ini` back into git.
