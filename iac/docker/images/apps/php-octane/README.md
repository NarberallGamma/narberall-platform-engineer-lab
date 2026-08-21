# PHP Octane (Swoole)

**Business first:** a Laravel shop API on **Octane/Swoole** is an image with extensions and `artisan optimize`, not `php artisan serve` in prod. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Compose: [`../../../compose/php-octane/`](../../../compose/php-octane/). AMQP consumers that reuse this class of image: [`../../../compose/php-amqp/`](../../../compose/php-amqp/). RoadRunner contrast: [`../php-roadrunner/`](../php-roadrunner/).

I used PHP 8.2 cli, Composer 2.5.5, `install-php-extensions` (pdo_mysql, amqp, sockets, swoole, redis, memcached), a production php.ini plus opcache, then `composer install --no-dev` and artisan cache steps.

```text
php-octane/
  Dockerfile
  docker/php/docker-php-opcache.ini
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Swoole + memcached + redis + amqp | One runtime for HTTP Octane and queue work |
| `artisan key:generate` / `optimize` / cache | Image bake, not a first-request warmup |
| Pinned installer | `mlocati/docker-php-extension-installer` 2.7.7 |

Laravel app source and `composer.json` are not in git. `COPY ./ /app` has nothing to install. Compose starts `php artisan octane:start` on port 3000 against `example.registry/shop-app/...`.

```bash
# needs the omitted Laravel tree as build context
docker build -t example.registry/shop-app/shop-app:1.0.0 -f Dockerfile .
```

**Keywords:** PHP 8.2, Swoole, Laravel Octane, Composer, opcache
