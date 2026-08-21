# Shop laptop dependencies

**Business first:** a shop engineer’s laptop is **six small compose files**, not one 200-line stack that nobody starts. Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Full local estate: [`../java-local-dev/`](../java-local-dev/).

I used these files when a service needed one dependency at a time (Jaeger, Kafka+ZK, MinIO, Postgres, Keycloak, Locust). Each folder is the richest copy of that mechanic. They are not the Java app stacks.

```text
dev-deps/
  jaeger/      # OTLP all-in-one (otel-config.yml is not in git)
  kafka/       # ZooKeeper + Kafka, host 29092
  minio/       # API 9000 + console 9001
  postgres/    # Postgres 14, shop DB, host 5435
  keycloak/    # Keycloak 20.0.2 + Postgres (realm bind is a gap)
  locust/      # master + worker, shop order/offer flow
```

```bash
# from a child directory, after CHANGE_ME values and any missing bind files are in place:
docker compose up -d
```

## What hiring should see

| Folder | Mechanic |
|--------|----------|
| [`jaeger/`](jaeger/) | OTLP collector + UI. Volume path `./configs/otel-config.yml` is **missing** |
| [`kafka/`](kafka/) | Classic ZK + broker. Not the KRaft topic bootstrap |
| [`minio/`](minio/) | Object store with `CHANGE_ME` root keys |
| [`postgres/`](postgres/) | Shop DB only. Init SQL is commented out |
| [`keycloak/`](keycloak/) | Stock quay image + `--import-realm`. Realm JSON is **not** next to this file |
| [`locust/`](locust/) | Master/worker and a sequential shop HTTP flow |

## Honest gap

`docker compose up` is not a one-command demo for every folder. Keycloak bind-mounts `./import/realm-export.json` (absent). Jaeger bind-mounts `./configs/otel-config.yml` (absent). Locust needs a reachable shop API and filled `CHANGE_ME` passwords. An example realm lives on the Keycloak **image** at [`../../images/apps/keycloak/import/realm-export.json`](../../images/apps/keycloak/import/realm-export.json); this compose does not copy it.

KRaft + topic bootstrap is [`../java-local-dev/java-kraft-topics/`](../java-local-dev/java-kraft-topics/). Custom SPI Keycloak is [`../java-local-dev/keycloak-spi/`](../java-local-dev/keycloak-spi/).

**Keywords:** laptop deps, Jaeger, Kafka, MinIO, Postgres, Keycloak, Locust
