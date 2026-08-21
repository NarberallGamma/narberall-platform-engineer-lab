# PHP RoadRunner

**Business first:** an older PHP API can still be a **RoadRunner worker image**, not a leftover php-fpm vhost. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Compose: [`../../../compose/php-roadrunner/`](../../../compose/php-roadrunner/). Octane contrast: [`../php-octane/`](../php-octane/).

I used PHP 7.4 cli, Composer 1.10, the `spiralscout/roadrunner:1.9.2` binary copied to `/usr/local/bin/rr`, a wide `install-php-extensions` set (amqp, imagick, redis, sysv*, zip), then `composer install` and Doctrine proxy generation.

```text
php-roadrunner/
  Dockerfile
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `COPY --from=roadrunner /usr/bin/rr` | Runtime is the `rr` binary, not php-fpm |
| Extension list | Legacy API surface (gd, imagick, ffi, xsl, sysv*) |
| `doctrine orm:generate-proxies` | ORM warmup in the image |
| PHP 7.4 + Composer 1 | Honest pin, not a silent upgrade |

App source, `composer.json`, and `.rr.yml` are not in git. Compose runs `rr serve -d -c .rr.yml` and still points at `docker/Dockerfile` as in the original app tree.

```bash
# needs the omitted PHP tree as context (compose uses dockerfile: docker/Dockerfile)
docker build -t api-service-cli:local -f Dockerfile .
```

**Keywords:** PHP 7.4, RoadRunner, Doctrine, Composer 1
