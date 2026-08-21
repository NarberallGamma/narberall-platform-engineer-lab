# Nginx SPA + envsubst

**Business first:** a static shop front is **nginx plus a start-time `config.js`**, not another Next standalone image. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Next sibling: [`../node-frontend/`](../node-frontend/).

I used this when the UI was a CRA/Vite `build/` folder: Node 20 compiles, nginx 1.21 serves, `envsubst` writes `config.js` from `config.template.js` on start. Path `/app/loan` is the in-app alias (generic). The front source is not in git.

```text
node-nginx-spa/
  Dockerfile     # node:20-alpine builder → nginx:1.21.0-alpine, envsubst then nginx
  nginx.conf     # listen 3000, try_files SPA, /app/loan alias
```

```bash
# from this directory, after the front tree (package.json, lockfile, src) is the context:
docker build -t example.registry/shop-app/node-nginx-spa:local .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Two stages | `npm ci --force` + `npm run build`, then static files on nginx |
| `envsubst` CMD | Stand URLs land in `config.js` at start, not at `docker build` |
| `nginx.conf` | SPA `try_files` and one aliased route |
| Port note | File `EXPOSE 80`; `nginx.conf` listens **3000**. That mismatch is in the source |

## Honest gap

App source, `package.json`, and `config.template.js` are not in this folder. `COPY` / `envsubst` expect those files. A rebuild from this directory alone fails.

This is **not** [`../node-frontend/`](../node-frontend/). Next standalone emits `server.js`. This image is nginx + runtime envsubst.

**Keywords:** nginx, envsubst, SPA, node 20 Alpine, static assets
