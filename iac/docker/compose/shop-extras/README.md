# Shop extras (host compose)

**Business first:** NiFi, a docs portal, a fluent-bit sidecar, and a static-site build are **four small compose files**, not extra services stuffed into the Java local stack. Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Java stacks: [`../java-local-dev/`](../java-local-dev/). NiFi image: [`../../images/apps/nifi/`](../../images/apps/nifi/). NiFi Helm: [`../../../helm/reference/helm-data-plane/nifi/`](../../../helm/reference/helm-data-plane/nifi/).

I landed these next to the Java kit (not inside it). They are shop host mechanics that are not a Java dependency list.

```text
shop-extras/
  nifi/                 # apache/nifi:2.6.0, single-user, proxy host
  docs-portal/          # nginx target + PlantUML (Dockerfile and .env are gaps)
  fluent-bit-sidecar/   # fluent/fluent-bit:4.0.12-debug, bind ./ as config
  static-site-build/    # four-line build-only compose
```

```bash
# from a child directory, after that folder's gaps are closed:
docker compose up -d
```

## What hiring should see

| Folder | Mechanic |
|--------|----------|
| [`nifi/`](nifi/) | Same 2.6.0 pin as the packaging image and the Helm chart. Password `CHANGE_ME` |
| [`docs-portal/`](docs-portal/) | Docs UI + PlantUML. `env_file: .env` and `build` target `nginx` |
| [`fluent-bit-sidecar/`](fluent-bit-sidecar/) | Real thin file: image + volume |
| [`static-site-build/`](static-site-build/) | Real thin file: `build: context: .` only |

## Honest gap

Docs portal has no Dockerfile and compose expects `.env` (only `.env.example` is here). Fluent-bit has no `fluent-bit.conf`. Static-site has no Dockerfile. NiFi compose does not build the packaging image (no `cacerts` / JDBC layer).

**Keywords:** NiFi, docs portal, fluent-bit, static site, shop extras
