# Node 18 Vite helper (install vs watch)

**Business first:** front assets on the PHP stand are a **Node 18 sidecar** that runs `npm install` or `npm install` + `npm run watch`, not a dist baked into the FPM image. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Compose: [`../../../compose/php-dev/`](../../../compose/php-dev/). Next.js standalone is a different mechanic: [`../node-frontend/`](../node-frontend/).

I used the install-only entry on the default shop-app compose and the watch entry on the Vue file. Both Dockerfiles are `node:18.12.0`. The scripts differ. A cartesian M1+watch compose was not published.

```text
node-vite/
  Dockerfile          # COPY npm.sh, ENTRYPOINT install
  Dockerfile.watch    # COPY npm-watch.sh as /npm.sh, then npm run watch
  npm.sh
  npm-watch.sh
```

```bash
# from this directory:
docker build -t example.registry/shop-app/node-vite:local -f Dockerfile .
docker build -t example.registry/shop-app/node-vite:watch -f Dockerfile.watch .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Two Dockerfiles | Same base, two entries. Watch is not a compose-only flag |
| `npm.sh` | `npm cache clear` + `npm install` |
| `npm-watch.sh` | Same, then `npm run watch` |
| Pin `18.12.0` | Shop front of that year. Not Node 22 |

## Honest gap

`package.json`, lockfile, and the Vue/Vite tree are not in this folder. The container bind-mounts `/path/to/app`. A rebuild here only proves the entrypoint scripts.

**Keywords:** Node 18, npm, Vite, watch, PHP sidecar
