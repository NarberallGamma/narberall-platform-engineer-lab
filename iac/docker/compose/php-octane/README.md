# PHP Octane compose

**Business first:** Octane is a **named server container** on port 3000, plus a cli twin of the same image. Image: [`../../images/apps/php-octane/`](../../images/apps/php-octane/). AMQP consumers: [`../php-amqp/`](../php-amqp/). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

```text
php-octane/
  docker-compose.yml
  .env.example          # example.registry / shop-app / port 3000
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `octane:start --host=0.0.0.0 --port=3000` | The HTTP command, not php-fpm |
| `${DOCKER_REPOSITORY}/shop-app/...` | Registry pin from env, not a hard host |
| Unused `mysql` volume | Published as found |

There is no `build:` key. Compose expects an image that was already built from the omitted Laravel tree.

```bash
cp .env.example .env
# build the image from images/apps/php-octane with the app tree as context
docker compose up -d
```

**Keywords:** Laravel Octane, Swoole, docker compose
