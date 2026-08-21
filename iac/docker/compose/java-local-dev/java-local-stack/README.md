# Full Java laptop stack (app commented)

**Business first:** the richest shop laptop estate is **Keycloak, two Postgres, MinIO, ZK/Kafka, kafka-ui, and WireMock**, with the app left commented so deps start first. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this file when a Java service needed every dependency pinned together (Kafka **7.4.0**, healthchecks, extra DBs in `init.sql`). The Spring service block stays commented, as in the source.

```text
java-local-stack/
  docker-compose.yml    # KC + PG + MinIO + Kafka 7.4.0 + UI + WireMock
  init.sql              # notification + tariff DBs
```

```bash
# from this directory, after ./keycloak/import/realm-export.json exists
# and ./wiremock has mappings (or the wiremock service is removed):
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| App commented | Deps are the product of this file |
| Kafka 7.4.0 + kafka-ui | Pinned broker plus a UI on 19092 |
| `init.sql` | Extra shop DBs, not only `POSTGRES_DB=shop` |
| WireMock `:8085` | HTTP stubs for partner trees |

## Honest gap

`./keycloak/import/realm-export.json` is **not** here. `./wiremock` mappings and the large product-tree fixture are **not** here. `docker compose up` fails on those binds. An example realm lives on [`../../../images/apps/keycloak/import/realm-export.json`](../../../images/apps/keycloak/import/realm-export.json). `/home/wiremock` is the **upstream container path**, not a host home.

**Keywords:** Java local stack, Keycloak, Kafka 7.4.0, WireMock, MinIO
