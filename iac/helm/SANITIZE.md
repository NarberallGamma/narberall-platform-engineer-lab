# Sanitize before publish (Helm)

Same habit as [`../terraform/SANITIZE.md`](../terraform/SANITIZE.md) and [`../ansible/SANITIZE.md`](../ansible/SANITIZE.md). Kits under [`reference/`](reference/) are living trees (custom templates, values excerpts, thin wrappers). [`apps/`](apps/) is curated product samples (one richest copy per mechanic). Secrets stay out of git.

- Generic names: `platform`, `estate`, `app`, `*.example.com`
- No employer / client brands, personal surnames, Windows paths, or dump paths
- CIDRs: documentation ranges only (`10.10.x.x`, `203.0.113.x`, `198.51.100.x`)
- Registries and Helm repos: `oci://example.registry/helm/common`, `https://charts.example.com`
- Passwords and tokens: `CHANGE_ME` or `*.example` files only
- Never commit PEM/PFX, `*.key` (except documented `.example`), kubeconfig, vault tokens, `secret-values.yaml`, `.werf_secret_key`, Argo repo/cluster secrets
- Fake UUIDs `00000000-0000-4000-8000-...`
- Vendor chart trees (Grafana, Prometheus, OpenObserve, Strimzi CRDs, AKHQ, Bitnami Kafka, Bitnami Keycloak, codecentric Keycloak tarball, full Vault, Dagster `charts/`) stay out. Pin the version and the values keys in README
- [`apps/`](apps/) is a curated SAMPLE set. Do not publish Argo Application lists, vendor `.tgz`, or twenty-six estate clones that only change ExternalSecret keys
- Alert and dashboard titles: drop live emails, Telegram names, SQL request ids, and product hostnames
- Line endings: LF only
