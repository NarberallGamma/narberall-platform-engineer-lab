# Static nginx site

**Business first:** a brochure site is nginx plus files, not a CMS. I used this Ubuntu + nginx image for a corporate static tree: gzip, cache headers, `/health`, logs on stdout.

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

```text
static-nginx/
  docker/
    Dockerfile            # ubuntu:24.04, nginx, HEALTHCHECK
    nginx.conf            # SPA try_files, /health
    .dockerignore
```

## Honest gap

Site assets (`index.html`, CSS, JS, logos) are **not** in this lab. The Dockerfile `COPY`s them from the **site root** (parent of `docker/`). A build from this folder alone fails on those `COPY` lines. That is expected.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Ubuntu + nginx | Not alpine-from-hub only. One layer install, default site removed, logs to stdout/stderr. |
| Conf next to the image | `docker/nginx.conf` is the vhost the image actually ships. |
| Health | `curl -f http://localhost/` in the image; `/health` in the vhost. |

Build context is the site root (the directory that holds `index.html` and `docker/`):

```bash
docker build -f docker/Dockerfile -t example.registry/estate/static-nginx:1.0 .
docker run --rm -p 8080:80 example.registry/estate/static-nginx:1.0
```

Placeholders only. Brand logos and live copy stay out.
