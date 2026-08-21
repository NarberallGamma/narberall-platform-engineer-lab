# Next.js standalone (node)

**Business first:** the shop console is a **four-stage Next image** (deps from the lockfile, build with public env, thin `standalone` runner), not `npm start` on a fat node_modules layer. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Nginx SPA sibling: [`../node-nginx-spa/`](../node-nginx-spa/). Unit-test image: [`../vitest/`](../vitest/).

I used this Dockerfile for the Next standalone front. Private UI-kit packages resolve through the `.npmrc` in this folder (`@shop-app` → `npm.example.com`, password `CHANGE_ME`). [`../vitest/`](../vitest/) shares this file. A second committed copy stays out.

```text
node-frontend/
  Dockerfile    # node:22-alpine, stages base / deps / builder / runner
  .npmrc        # public npm + placeholder private scope (the one copy)
```

```bash
# from this directory, after the Next tree (package.json, lockfile, app) is the context:
docker build -t example.registry/shop-app/node-frontend:local \
  --build-arg VERSION=0.0.1 \
  --build-arg NEXT_PUBLIC_API_URL=https://shop.example.com \
  .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `deps` then `builder` | `npm ci` from lockfile only, then `COPY .` for the build |
| `NEXT_PUBLIC_*` ARGs | Version, client id, API and WS URLs baked at build |
| `standalone` runner | `server.js` + `.next/static`, user `nextjs` 1001, port 3000 |
| One `.npmrc` | Private registry contract. Vitest points here |

## Honest gap

App source, `package.json`, and `package-lock.json` are not in this folder. `COPY` lines expect a real Next tree. A rebuild from this directory alone fails. Live registry auth stays out (`CHANGE_ME` only).

**Keywords:** Next.js, standalone, npm ci, node 22 Alpine, private npm
