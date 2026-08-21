# PHP local-dev compose (8.1 / 7.4 / 8.4+Supervisor / OMS)

**Business first:** a shop PHP estate is **four process models**, not one `docker-compose.yml` cloned per product. Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Images: [`../../images/apps/php-fpm/`](../../images/apps/php-fpm/). Helm/werf form of the 8.1 family: [`../../../helm/apps/werf-raw/`](../../../helm/apps/werf-raw/).

I used these files as the local stands next to the published images. App source is not in git. Bind mounts point at `/path/to/app`. Image `build:` paths point at `../../images/apps/...`. Env files are `*.env.example` with `CHANGE_ME` only.

```text
php-dev/
  shop-app.yml            # PHP 8.1, 3 FPM, memcached trio, Composer, Node, cron/queue
  shop-app-vue.yml        # same + node-vite Dockerfile.watch
  shop-app-m1.yml         # arm64v8/mysql:oracle, native-password, no PMA/Xdebug
  shop-app-e2e.yml        # php-ci/tests + Selenium 3.11 + inline env
  shop-app.env.example
  shop-dashboard.yml      # sidecar MySQL + load_dump.sh
  shop-dashboard.env.example
  shop-api.yml            # PHP 7.4 + Redis (nginx-php substitute)
  shop-api.env.example
  sticker-api.yml         # PHP 8.4 + Supervisor, Postgres pair, Rabbit 4.0.4
  sticker-api.env.example
  oms-dev.yml             # werf tags, 2 Postgres, Phinx init containers
  oms.yml                 # local php-oms build, 5 Postgres
  oms.env.example
  broker.yml              # Rabbit 4.0.5 + Redis AOF (no PHP image)
```

```bash
# from this directory, after /path/to/app holds the matching PHP tree:
docker compose -f shop-app.yml up --build
docker compose -f shop-app-vue.yml up --build
docker compose -f shop-app-m1.yml up --build
docker compose -f shop-app-e2e.yml up --build
docker compose -f shop-dashboard.yml up --build
docker compose -f shop-api.yml up --build
docker compose -f sticker-api.yml --env-file sticker-api.env.example up --build
docker compose -f oms.yml up --build
# oms-dev.yml needs $WERF_*_DOCKER_IMAGE_NAME and external network shop_oms_bridge
docker compose -f broker.yml up
```

## What hiring should see

| Pattern | Files | Mechanic |
|---------|-------|----------|
| PHP **8.1** | `shop-app.yml`, `-vue`, `-m1`, `-e2e`, `shop-dashboard.yml` | Laravel: 3× FPM, memcached, artisan migrate/cron/queue, Composer 2.3.5, Node 18. Dashboard adds a dump-loading sidecar MySQL |
| PHP **7.4** | `shop-api.yml` | `phpdockerio` FPM, Redis, two workers. Front image is [`nginx-php`](../../images/apps/nginx-php/) |
| PHP **8.4 + Supervisor** | `sticker-api.yml` | Official 8.4, AMQP consumers, Postgres + autotest DB, stock nginx |
| **OMS** | `oms-dev.yml`, `oms.yml` | Phinx init, 2 or 5 Postgres, Rabbit, keepalive sysctls. DEV uses werf image env vars. Local file builds [`php-oms`](../../images/apps/php-oms/) |
| Broker only | `broker.yml` | Rabbit 4.0.5 + Redis AOF. No PHP Dockerfile (server image was werf/.NET) |

Vue watch is `shop-app-vue.yml`. ARM MySQL is `shop-app-m1.yml`. Those are two files, not one cartesian product.

## Honest gap

- App trees, `vendor/`, dumps, and live `.env` are not here. `up` without `/path/to/app` only starts the deps.
- `load_dump.sh` expects gzipped SQL that was not copied.
- Cron still calls `/app/.docker/images/php/cron.sh` inside the app tree.
- e2e compose mounts ini at `/etc/php/7.2/...` and uses `extra_hosts` `172.17.0.1`.
- `oms-dev.yml` is not a local build. Tags come from `$WERF_*`.
- `oms.yml` has five Postgres services. Init uses `docker-dev-init-entrypoint-testing.sh`.
- `php-fpm-legacy/composer` still needs [`composer.sh`](../../images/apps/composer/composer.sh) in its build context.

**Keywords:** Docker Compose, PHP 8.1, PHP 7.4, PHP 8.4, Supervisor, OMS, Phinx, Laravel, Selenium, RabbitMQ
