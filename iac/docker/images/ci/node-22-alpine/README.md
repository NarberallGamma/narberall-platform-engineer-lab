# Node 22 Alpine (CI)

**Business first:** Node 22 jobs need the public Alpine tag plus musl `libc6-compat` so native addons that expect glibc symbols do not fail on the first `npm ci`.

The `FROM` line is a registry retag of `node:22-alpine`. The `RUN` is the only estate layer.

```text
node-22-alpine/
  Dockerfile
```

```bash
docker build -t example.registry/ci/node:22-alpine -f Dockerfile .
```

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
