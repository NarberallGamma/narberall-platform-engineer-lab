# PHP 8.4-FPM + Supervisor (AMQP + Postfix)

**Business first:** an 8.4 API runs **php-fpm, Supervisor consumers, and Postfix in one container** (dumb-init), not the 8.1 memcached/Laravel family. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). OMS sibling (8.4 without Supervisor): [`../php-oms/`](../php-oms/). Compose: [`../../../compose/php-dev/sticker-api.yml`](../../../compose/php-dev/sticker-api.yml).

I used this image when the API needed pcntl, pgsql, and two AMQP workers next to FPM. Nginx is stock `nginx:stable-alpine` plus `nginx/default.conf` (not [`../nginx-php/`](../nginx-php/)). Swoole / RoadRunner stands are a later slice, not this folder.

```text
php-api/
  Dockerfile           # php:8.4-fpm, Supervisor, Postfix, pdo_pgsql, pcntl, dumb-init 1.2.5
  supervisord.conf     # test-queue-consumer + print-queue-consumer
  xdebug.ini
  nginx/default.conf   # fastcgi_pass php_api:9000
```

```bash
# from this directory:
docker build -t example.registry/sticker-api/php:local .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `php:8.4-fpm` | Official image, not buster. Locale `en_US`, TZ `Europe/Moscow` |
| Supervisor + pcntl | Queue consumers in the same PID tree as FPM |
| Postfix spool copy | `/etc/services` into `/var/spool/postfix` so the MTA starts |
| `dumb-init` 1.2.5 | PID 1 for the mixed process set |
| `pdo_pgsql` | Postgres, not MySQL. Compose has a second autotest DB |
| Stock nginx + conf | Single upstream `php_api:9000`, 32m body, no TLS block |

This is **not** [`../php-fpm/`](../php-fpm/) and **not** [`../php-oms/`](../php-oms/). OMS is Phinx init containers and pool config. This file is Supervisor + Postfix on 8.4.

## Honest gap

App source, `bin/cli.php`, and a stock Postfix `main.cf` are not in this folder. `supervisord.conf` still calls `/app/bin/cli.php`. Composer is installed twice in the Dockerfile (source leftover). Xdebug is built, not enabled (`docker-php-ext-enable` is commented).

**Keywords:** PHP 8.4, Supervisor, pcntl, Postfix, dumb-init, pgsql, AMQP
