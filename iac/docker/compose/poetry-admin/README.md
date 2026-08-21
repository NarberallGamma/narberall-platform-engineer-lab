# Poetry admin compose (Postgres + RabbitMQ)

**Business first:** the admin API image expects a **broker and a database with healthchecks**, not a hope that localhost already has them. Image: [`../../images/apps/poetry-admin/`](../../images/apps/poetry-admin/). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

This stack is only the two sidecars. The admin container is not in the file. Passwords are `CHANGE_ME`.

```text
poetry-admin/
  docker-compose.yaml   # postgres:latest + rabbitmq:3-management
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Healthchecks | `pg_isready` and `rabbitmqctl status` before dependents start |
| Named volumes | `postgres_data` / `rabbitmq_data` |
| No app service | The Poetry image is a separate build; this file is the estate deps |

```bash
docker compose up -d
# admin image (needs omitted app source) talks to :5432 and :5672
```

**Keywords:** Postgres, RabbitMQ, healthcheck, Poetry admin
