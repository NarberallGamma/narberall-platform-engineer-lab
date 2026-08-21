# Vitest CI image

**Business first:** unit tests run in the **same Node 22 image and lockfile** as the Next front, before a product build. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Front image: [`../node-frontend/`](../node-frontend/).

I used this Dockerfile as `Dockerfile.vitest` next to the Next app. `npm ci` needs the private UI-kit scope. **Share** [`../node-frontend/.npmrc`](../node-frontend/.npmrc). A second committed copy stays out (the files were byte-identical). Place that file in this build context (copy or symlink named `.npmrc`) for `docker build`. The app tree is not in git.

```text
vitest/
  Dockerfile    # node:22-alpine, libc6-compat, npm ci, lockfile-switch test
                # COPY .npmrc → use ../node-frontend/.npmrc in the context
```

```bash
# from this directory, after the Next tree is the context and .npmrc is present:
ln -s ../node-frontend/.npmrc .npmrc
docker build -t example.registry/shop-app/vitest:local \
  --build-arg VERSION=0.0.1 \
  .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Lockfile switch | yarn / npm / pnpm test, with `package-lock.json` required for `npm ci` |
| Tests before build | `RUN` is `npm run test`, not `npm run build` |
| Shared `.npmrc` | One private-registry contract with [`../node-frontend/`](../node-frontend/) |
| `libc6-compat` | Alpine Node extras some native deps need |

## Honest gap

App source, `package.json`, and `package-lock.json` are not in this folder. `COPY .npmrc package.json package-lock.json` expects those files plus the shared `.npmrc`. A rebuild from this directory alone fails.

**Keywords:** Vitest, npm ci, node 22 Alpine, lockfile, private npm
