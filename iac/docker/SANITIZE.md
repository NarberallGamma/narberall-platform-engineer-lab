# Sanitize before publish (Docker / Compose)

Same habit as [`../terraform/SANITIZE.md`](../terraform/SANITIZE.md), [`../ansible/SANITIZE.md`](../ansible/SANITIZE.md), and [`../helm/SANITIZE.md`](../helm/SANITIZE.md). [`images/`](images/) is one richest Dockerfile per mechanic. [`compose/`](compose/) is living host and local stacks. Secrets stay out of git.

- Generic names: `platform`, `estate`, `shop-app`, `*.example.com`
- No employer / client brands, personal surnames, Windows paths, or dump paths
- CIDRs: documentation ranges only (`10.10.x.x`, `203.0.113.x`, `198.51.100.x`)
- Registries: `example.registry/...`
- Passwords and tokens: `CHANGE_ME` or `*.example` files only
- Never commit PEM/PFX, `*.key` (except documented `.example`), kubeconfig, vault tokens, live `.env`
- Fake UUIDs `00000000-0000-4000-8000-...`
- Telegram chat ids: `-1000000000001`
- One richest copy per mechanic. Do not publish a hundred-plus identical shop Dockerfiles
- Hunter hubs describe scope in general terms. Private dump filenames stay out of README lists
- One-line `FROM` pins are honest retags (kaniko, node base), not generated tutorials
- Line endings: LF only
