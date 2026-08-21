# Static site build (thin)

**Business first:** some shop fronts were **compose as a build wrapper** (`build: context: .`) with no services story. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Node images: [`../../../images/apps/node-frontend/`](../../../images/apps/node-frontend/), [`../../../images/apps/node-nginx-spa/`](../../../images/apps/node-nginx-spa/).

I kept this four-line file because that is the real compose. It only names a build context.

```text
static-site-build/
  docker-compose.yml    # services.app.build.context: .
```

```bash
# from this directory, after a Dockerfile exists in the context:
docker compose build
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Four lines | Honest thin file, not a generated tutorial |
| Build only | No ports, no env, no command |

## Honest gap

No Dockerfile and no site source in this folder. `docker compose build` fails. The richer Next and nginx SPA Dockerfiles are the images above, not this compose.

**Keywords:** static site, compose build, thin
