# PHP 8.1-FPM (Laravel local-dev)

**Business first:** a shop PHP backend is one **8.1-FPM image** (gd+webp, memcached from source, Xdebug, uid 1000), not a Dockerfile per service. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Compose: [`../../../compose/php-dev/`](../../../compose/php-dev/). CI sibling: [`../php-ci/`](../php-ci/). Nginx: [`../nginx-php/`](../nginx-php/). Composer: [`../composer/`](../composer/). Helm form of the same family: [`../../../../helm/apps/werf-raw/`](../../../../helm/apps/werf-raw/).

I used this image for the richest Laravel local stand: three FPM workers, a migrate container, queue worker, and a cron loop that calls `artisan schedule:run`. The app tree is not in git.

```text
php-fpm/
  Dockerfile                 # php:8.1-fpm-buster, gd+webp, memcached 3.2.0, xdebug
  php-ini-overrides.ini
  xdebug.ini
  cron.sh                    # wait for MySQL + vendor, then schedule:run
  migrate.sh                 # artisan migrate --force + seed + ide-helper
  migrate-test.sh
  sidecar-mysql/load_dump.sh # second MySQL: N named DBs + billing + shop_conf
```

```bash
# from this directory (image only; app is a bind mount on compose):
docker build -t example.registry/shop-app/php-fpm:local .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `php:8.1-fpm-buster` | Canonical shop PHP. Not 7.4, not 8.4 |
| gd `--with-webp` | Product uploads needed webp. The 8.2 sibling did not |
| memcached 3.2.0 from source | `pecl` was not enough on this base |
| DST Root CA X3 off | `ca-certificates` pin so expired Let's Encrypt roots do not break curl |
| `usermod -u 1000` | Bind-mount writes match a host developer uid |
| Sidecar `load_dump.sh` | Dashboard compose loads gzipped dumps into several DBs |

This is **not** [`../php-fpm-legacy/`](../php-fpm-legacy/) (7.4 + Redis), **not** [`../php-api/`](../php-api/) (8.4 + Supervisor), and **not** [`../php-oms/`](../php-oms/) (Phinx + Postgres).

## Honest gap

App source, `vendor/`, and the SQL dumps (`shop.sql.gz`, `billing.sql.gz`, `shop_conf.sql.gz`, `testdata.sql`) are not in this folder. `load_dump.sh` still names those files. Cron on compose still runs `/app/.docker/images/php/cron.sh` inside the bind-mounted app tree. Dashboard compose mounts the ini at an 8.2 path (source leftover; the image is 8.1).

**Keywords:** PHP 8.1, FPM, Laravel, memcached, Xdebug, gd webp, MySQL sidecar
