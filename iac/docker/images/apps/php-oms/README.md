# PHP 8.4 OMS (Phinx, pool, init scripts)

**Business first:** an order-management stand is **Phinx migrations, 2 to 5 Postgres, Rabbit, and keepalive sysctls**, not another Laravel FPM trio. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Supervisor 8.4 sibling: [`../php-api/`](../php-api/). Compose: [`../../../compose/php-dev/oms-dev.yml`](../../../compose/php-dev/oms-dev.yml), [`../../../compose/php-dev/oms.yml`](../../../compose/php-dev/oms.yml).

I used this image with a pool under `php/` and init scripts that `createdb`, tune Postgres, then `vendor/bin/phinx migrate` for orders / report / history. `oms-dev.yml` consumes `$WERF_*_DOCKER_IMAGE_NAME`. `oms.yml` builds this folder and keeps five Postgres services. The init pattern file is `docker-dev-init-entrypoint-testing.sh`.

```text
php-oms/
  Dockerfile
  ini/php.ini  ini/php-fpm.conf
  php/www.conf  php/docker.conf  php/zz-docker.conf
  nginx.conf
  scripts/docker-dev-start-oms.sh
  scripts/docker-dev-init-entrypoint.sh
  scripts/docker-dev-init-entrypoint-testing.sh
  scripts/docker-dev-init-conditional.sh
  scripts/docker-migrations.sh
  scripts/docker-application.sh      # postfix master + php-fpm
  scripts/docker-run-all.sh
  scripts/php-fpm-sudoer
  scripts/psql-config.sql
```

```bash
# from this directory:
docker build -t example.registry/shop-oms/php:local .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `php:8.4-fpm` without Supervisor | Same major as [`../php-api/`](../php-api/), different process model |
| Xdebug **3.4.2** pin | API image uses unpinned `pecl install xdebug` |
| Pool files | `www.conf` / `docker.conf` / `zz-docker.conf`, not stock `www.conf.default` |
| Phinx on three configs | `orders_delivery` / `report` / `history` |
| `psql-config.sql` + `pg_reload_conf` | Init container tunes the engine, then migrates |
| JSON nginx access log | `combined_plus` + `X-Forwarded-For` real IP |
| Keepalive sysctls on compose | `tcp_keepalive_*` + `somaxconn` on the PHP service |

## Honest gap

App source, Phinx configs, `recreateDev.php` / `recreateTest.php`, and SQL dumps are not in this folder. Scripts still call `/app/docker/php-oms/scripts/...` and `/app/migrations/...` (original in-app layout). Stock Postfix `main.cf` was omitted; `docker-application.sh` still starts `postfix` master. Parallel test DBs stay on `oms.yml`; only the host-suffix init scripts were dropped.

**Keywords:** PHP 8.4, OMS, Phinx, Postgres, RabbitMQ, php-fpm pool, init container
