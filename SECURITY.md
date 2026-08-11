# Security

Do not open issues with secrets. Rotate any credential that may have been exposed.

## Before every push

Follow [`docs/security-sanitize.md`](docs/security-sanitize.md).

Forbidden in this repo:

- Production `.tfvars`, kubeconfigs, private keys, tokens
- Client hostnames, internal URLs, ticket keys
- Home LAN IPs, VPN configs with credentials

Allowed:

- `*.example` configs
- Generic names (`project-a`, `example.com`)
- Architecture diagrams without identifiable infra
