# Sanitize notes (this tree)

What was removed or rewritten before publish:

- Employer / client brands and AD DNS
- Live inventory IPs (documentation ranges only)
- Vault tokens and SSH public keys (CHANGE_ME / dummy ed25519)
- EDR packages, wildcard TLS, bootstrap / root / VPS credential dumps
- Kafka CA PEM (placeholder file remains so the role path stays valid)
- Windows / WSL / dump / personal home paths
- GitLab include project renamed to `platform/common-ci`

What stayed (on purpose):

- Full role graphs: prepare_servers, docker_app family, night-park operator, node-exporter, Vault, estate_databases
- Jinja for nginx / keepalived / Vault Raft / Envoy / CryptoPro bootstrap
- All inventory host groups (prod, preprod, demo, localhost)
- Russian operator comments inside roles (original operator language)

PREPROD is the same Ansible tree as PROD. It is not published twice.

Do not add real certificates, tokens, or connection strings back into git.
