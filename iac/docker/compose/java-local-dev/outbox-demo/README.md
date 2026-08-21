# Outbox library demo (Postgres + Kafka)

**Business first:** the shop outbox is a **partitioned table plus a broker**, not a blog `INSERT` into `outbox`. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this file next to the shared outbox library. Postgres 14 loads `init.sql` (`outbox_messages` partitioned by `created_at`, plus a `users` table). ZooKeeper + Kafka sit beside it. No app container.

```text
outbox-demo/
  docker-compose.yml    # Postgres 14 outbox DB + ZK + Kafka
  init.sql              # partitioned outbox_messages
```

```bash
# from this directory, after setting POSTGRES_PASSWORD:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `PARTITION BY RANGE (created_at)` | Operational outbox, not a single heap table |
| Composite PK `(id, created_at)` | Required for the range partition |
| Retry / version columns | `count_retry`, `version`, jsonb headers |

## Honest gap

Library Java source and the publisher job are not in this folder. Kafka is `latest` (source pin). Init does not create child partitions; a first insert still needs a partition or a follow-up `CREATE TABLE … PARTITION OF`.

**Keywords:** outbox, partitioned table, Kafka, Postgres 14
