# Superset + Firefox (headless)

**Business first:** shop BI is **Apache Superset with a browser on the image**, so screenshot and alert jobs do not need a sidecar desktop. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this Dockerfile when Superset 4.1.1 had to drive Firefox ESR through geckodriver 0.36.0 under Xvfb. The base is the Apache scarf pin. `USER root` only for `apt` and the driver drop, then back to `superset`.

```text
superset/
  Dockerfile    # apache/superset:4.1.1, firefox-esr, geckodriver, xvfb
```

```bash
# from this directory (no extra context files):
docker build -t example.registry/shop-app/superset:4.1.1 .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Scarf pin `4.1.1` | Operated tag, not `latest` |
| Firefox + geckodriver | Headless UI jobs live in the same image as the server |
| `USER superset` | Root only for the package layer |

## Honest gap

Superset config, metadata DB, and the shop dashboards are not in this folder. This file only adds the browser toolchain. A `docker run` of the built image still needs the usual Superset env and a database.

**Keywords:** Apache Superset 4.1.1, Firefox ESR, geckodriver, Xvfb
