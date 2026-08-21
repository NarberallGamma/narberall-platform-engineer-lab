# PHP AMQP consumers

**Business first:** five queue workers are **five compose services, one image**, not five Dockerfiles. Octane-class image: [`../../images/apps/php-octane/`](../../images/apps/php-octane/). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

There is no consumer Dockerfile in this slice. The file reuses `example.registry/shop-app/${APP_NAME}:${APP_VERSION}` and runs `php artisan amqp:consume <name>`.

```text
php-amqp/
  docker-compose.yml
  .env.example
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Five named consumers | clients, clientsBalance, contractors, contractorsBalance, subscribeWebhook |
| Shared `app-logs` volume | One log dir, five processes |
| cli service with no command | Same image, interactive/debug twin |

```bash
cp .env.example .env
# image must already exist (Octane-class shop-app)
docker compose up -d
```

**Keywords:** AMQP, Laravel artisan, consumers, docker compose
