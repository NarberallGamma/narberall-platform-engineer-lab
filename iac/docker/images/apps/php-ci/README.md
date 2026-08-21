# PHP 8.1 CI + Selenium tests image

**Business first:** pipeline and browser jobs use a **slimmer 8.1 image** (Composer 1.10.17 pin, `COPY` of the app) plus a tests image, not the full local-dev FPM with Xdebug. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Runtime sibling: [`../php-fpm/`](../php-fpm/). Compose e2e: [`../../../compose/php-dev/shop-app-e2e.yml`](../../../compose/php-dev/shop-app-e2e.yml).

I used `php-for-ci` on the shop pipeline and the tests image as the three FPM workers next to Selenium. `testing/create.sh` is the MySQL init that creates `shop_app_testing`. The app tree is not in git.

```text
php-ci/
  Dockerfile              # php:8.1-fpm-buster, gd+zip, Composer 1.10.17, COPY ./ /app
  php-ini-overrides.ini
  tests/Dockerfile        # same memcached recipe as php-fpm, no xdebug
  tests/browsers.json
  testing/create.sh       # CREATE DATABASE shop_app_testing + GRANT
```

```bash
# CI image expects the PHP app as build context:
docker build -t example.registry/shop-app/php-ci:local -f Dockerfile /path/to/app

# tests image is self-contained (no COPY of the app):
docker build -t example.registry/shop-app/php-ci-tests:local -f tests/Dockerfile tests
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Composer **1.10.17** | Pipeline pin. Local helper is Composer **2.3.5** on [`../composer/`](../composer/) |
| `COPY ./ /app` | CI bakes the tree. Local FPM bind-mounts it |
| Tests image | Selenium workers share memcached + soap/mysqli, skip Xdebug |
| `create.sh` | Initdb hook used by shop-app / vue / m1 compose |

## Honest gap

App source is not in this folder. A rebuild of `Dockerfile` from here alone fails (`COPY ./ /app`). `create.sh` still embeds `CHANGE_ME` for the MySQL root password. e2e compose mounts the FPM ini at a leftover `/etc/php/7.2/...` path.

**Keywords:** PHP 8.1, Composer 1.10, CI, Selenium, MySQL init
