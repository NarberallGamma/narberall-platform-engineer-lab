# PHP 7.4-FPM (legacy API + Redis)

**Business first:** a 7.4 mobile API is a **different base** (`phpdockerio/php:7.4-fpm`) with Redis and two FPM workers, not a version bump of the 8.1 buster image. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Canonical 8.1: [`../php-fpm/`](../php-fpm/). Compose: [`../../../compose/php-dev/shop-api.yml`](../../../compose/php-dev/shop-api.yml).

I used this pair when the API could not move off 7.4. The FPM image is four packages (`mysql`, `intl`, `bcmath`, `mysql-client`). The Composer image is 7.4 + Composer **2.7.7** and no `git`/`gd`. The helper script is the same file as [`../composer/composer.sh`](../composer/composer.sh). It is not duplicated here.

```text
php-fpm-legacy/
  Dockerfile                 # phpdockerio/php:7.4-fpm + mysql/intl/bcmath
  php-ini-overrides.ini
  migrate.sh                 # artisan migrate --force + seed, then /app/migrated
  composer/Dockerfile        # 7.4, Composer 2.7.7, COPY composer.sh
```

```bash
# from this directory:
docker build -t example.registry/shop-api/php-fpm:local .

# Composer helper: place ../composer/composer.sh into composer/ first
docker build -t example.registry/shop-api/composer:local composer
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `phpdockerio/php:7.4-fpm` | Not `php:8.1-fpm-buster`. Different vendor base |
| Thin package list | No memcached-from-source, no webp, no xdebug |
| Composer **2.7.7** | Newer phar on the old runtime |
| Redis on compose | Session/cache/queue. The 8.1 stand uses memcached |

The TLS front for the 7.4 stand is [`../nginx-php/`](../nginx-php/), built from [`shop-api.yml`](../../../compose/php-dev/shop-api.yml).

## Honest gap

App source is not in this folder. `composer/Dockerfile` still `COPY composer.sh`. That file lives only under [`../composer/`](../composer/). A rebuild of the helper fails until the script is in that context. The published nginx is the TLS 8.1 front, not the dropped one-liner.

**Keywords:** PHP 7.4, phpdockerio, Redis, Composer 2.7.7, legacy FPM
