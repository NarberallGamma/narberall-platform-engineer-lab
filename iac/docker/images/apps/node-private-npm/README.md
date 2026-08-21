# Node private npm (SSH key ARG)

**Business first:** private Git dependencies are an **SSH key at build time**, discarded after the install stage. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used a Node 10 multi-stage image against `archive.debian.org` (stretch). The intermediate stage takes `GIT_SSH_PRIVATE_KEY` as a build ARG, writes `id_rsa`, `ssh-keyscan`s `git.example.com`, runs `npm install --production`, then the final stage copies `/usr/src/app` only. The ARG has **no sample value**.

```text
node-private-npm/
  Dockerfile
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Multi-stage | Key never lands in the runtime layer |
| `ARG GIT_SSH_PRIVATE_KEY` | The mechanic. A sample key stays out of git |
| `archive.debian.org` | Node 10 / stretch is a pin, not a current base |
| `ln -s …/.payments` | Payments dir name generalized |

`package.json`, lockfile, and `src/` are not in git. Build fails without them. A later publish should keep the ARG and never a sample key.

```bash
# pass the key only on a private builder; never bake it into a sample
docker build --build-arg GIT_SSH_PRIVATE_KEY -t example.registry/node-private-npm:local .
```

The `echo … >> tmp /root/.ssh/config` line is published as found (extra `tmp` token in the redirect).

**Keywords:** Node 10, private npm, SSH build ARG, multi-stage
