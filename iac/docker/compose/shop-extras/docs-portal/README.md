# Docs portal + PlantUML

**Business first:** shop architecture docs on the laptop are **a portal container plus PlantUML**, not a wiki paste. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this file when diagrams had to render next to the docs UI. Nginx is a multi-stage **build target**. PlantUML is `seaf/plantuml-server:jetty` on 8079. `VUE_APP_DOCHUB_*` keys are the upstream product API names, not an employer brand.

```text
docs-portal/
  docker-compose.yml    # docs-portal nginx target :8080 + plantuml :8079
  .env.example          # PlantUML URL, root manifest, git.example.com, CHANGE_ME token
```

```bash
# from this directory, after a Dockerfile with target nginx exists
# and .env is copied from .env.example:
# cp .env.example .env
docker compose up --build
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `target: nginx` | Image is a multi-stage docs build, not a stock nginx |
| PlantUML sibling | SVG server on 8079 |
| `.env.example` | Short template. The 384-line upstream example stays out |

## Honest gap

There is **no Dockerfile** in this folder. Compose `env_file: .env` (not `.env.example`). `docker compose up --build` fails until both exist. App source and the GitLab token stay out.

**Keywords:** docs portal, PlantUML, nginx target, env example
