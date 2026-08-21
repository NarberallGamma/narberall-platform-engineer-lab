# nginx with limit-upstream

**Business first:** a missing nginx module is a **compile from xenial**, not a hope that the distro package grew it. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I compiled nginx 1.12.1 with `--add-module=nginx-limit-upstream` (haosdent patch for 1.12.1), kept the debug binary, and shipped stock `nginx.conf` plus a default vhost. The maintainer email line from upstream was dropped on sanitize.

```text
nginx-limit-upstream/
  Dockerfile
  nginx.conf
  nginx.vh.default.conf
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Full `./configure` | SSL, stream, geoip, mail, http_v2, plus the extra module |
| git clone + patch | Module is not a `.so` COPY; it is built in |
| Debug vs stripped | `nginx-debug` and `nginx` both installed |
| xenial + 1.12.1 | Honest pin of the estate that needed this module |

Context is complete. Build pulls nginx.org and GitHub during `docker build`. The base is old on purpose.

```bash
docker build -t example.registry/nginx-limit-upstream:1.12.1 -f Dockerfile .
docker run --rm -p 8080:80 example.registry/nginx-limit-upstream:1.12.1
```

**Keywords:** nginx, limit-upstream, compile from source, xenial
