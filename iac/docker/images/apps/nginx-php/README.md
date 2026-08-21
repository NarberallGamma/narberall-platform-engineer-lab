# Nginx for PHP-FPM (TLS at build)

**Business first:** local HTTPS for the shop PHP stand is a **cert generated in the image**, not CRT/KEY in git. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). FPM: [`../php-fpm/`](../php-fpm/). Compose: [`../../../compose/php-dev/`](../../../compose/php-dev/).

I used `nginx:1.23-alpine` in front of three FPM workers. The original tree committed a localhost wildcard cert. That material stays out. `openssl req` writes `shop-app.example.com` at build.

```text
nginx-php/
  Dockerfile    # nginx:1.23-alpine, openssl self-signed, ADD nginx.conf
  nginx.conf    # upstream cluster php1/php2/php3, :80 subdomain, :443
```

```bash
# from this directory:
docker build -t example.registry/shop-app/nginx-php:local .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `openssl req` at build | No committed keys. CN `shop-app.example.com` |
| `upstream cluster` | Three FPM sockets (`shop-app-php1..3:9000`) |
| `server_name ~^(?<subdomain>.+)\.localhost$` | Tenant on HTTP via `SUBDOMAIN` fastcgi param |
| `:443` block | TLS server for the example CN |

[`../../../compose/php-dev/shop-api.yml`](../../../compose/php-dev/shop-api.yml) builds this image for the 7.4 stand.

## Honest gap

`/app/public` is a bind mount. A rebuild here only proves nginx + the self-signed pair.

**Keywords:** nginx, PHP-FPM upstream, TLS at build, wildcard localhost
