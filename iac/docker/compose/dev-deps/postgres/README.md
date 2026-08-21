# Postgres 14 (shop DB)

**Business first:** the laptop shop database is **one Postgres 14** on host port 5435, not a sidecar hidden inside the app compose. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this file when the app ran on the host or in another compose and only needed the DB. `POSTGRES_DB=shop`. An `init.sql` volume is present but **commented out**.

```text
postgres/
  docker-compose.yml    # library/postgres:14, shop, 5435, healthcheck, 256M cap
```

```bash
# from this directory, after setting POSTGRES_PASSWORD:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Host `5435` | Leaves 5432 free for a host Postgres |
| Healthcheck | Other stacks can `condition: service_healthy` |
| Memory cap | Laptop-safe `256M` |

## Honest gap

No `init.sql` in this folder. Extra shop DBs (`notification`, `tariff`) live on [`../../java-local-dev/java-local-stack/init.sql`](../../java-local-dev/java-local-stack/init.sql). A thin app+sidecar compose was **not** copied (same Postgres block as this file).

**Keywords:** Postgres 14, shop, 5435, healthcheck
