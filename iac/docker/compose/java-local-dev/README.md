# Java local-dev stacks

**Business first:** a shop Java laptop is **several compose files with different jobs**, not one file that comments half the services. Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Single-dep files: [`../dev-deps/`](../dev-deps/). Shop extras (NiFi, docs, fluent-bit, static site): [`../shop-extras/`](../shop-extras/).

I used these stacks for local Java work: a full dependency estate, a running app + deps, a host-Postgres service, KRaft with topic bootstrap, an outbox lib demo, and Keycloak with a custom SPI image. A laptop Postgres alone is [`../dev-deps/postgres/`](../dev-deps/postgres/).

```text
java-local-dev/
  java-local-stack/    # richest deps: KC + PG + MinIO + ZK/Kafka + UI + WireMock (app commented)
  java-app-stack/      # Spring app enabled + PG + MinIO + Keycloak
  java-host-db/        # shop-rate → host.docker.internal Postgres
  java-kraft-topics/   # KRaft 7.7.5, auto.create off, topic bootstrap
  outbox-demo/         # partitioned outbox table + ZK/Kafka
  keycloak-spi/        # custom keycloak-spi image + Postgres
```

```bash
# from a child directory, after CHANGE_ME values and missing binds (realm, wiremock) are in place:
docker compose up -d
```

## What hiring should see

| Folder | Job |
|--------|-----|
| [`java-local-stack/`](java-local-stack/) | Full laptop estate. App service is commented. WireMock volume is empty |
| [`java-app-stack/`](java-app-stack/) | App container is **on**. Same Keycloak bind gap. Host port **5438** is published twice (kept) |
| [`java-host-db/`](java-host-db/) | JDBC to host Postgres. Service is `shop-rate` |
| [`java-kraft-topics/`](java-kraft-topics/) | KRaft, advertised localhost, one-shot topic create |
| [`outbox-demo/`](outbox-demo/) | Lib demo: `outbox_messages` partitioned by `created_at` |
| [`keycloak-spi/`](keycloak-spi/) | Image from [`../../images/apps/keycloak/`](../../images/apps/keycloak/) |

## Honest gap

Realm JSON and WireMock mappings are **not** in these folders. `docker compose up` fails on those binds until local files exist. App JARs and Dockerfiles for `shop-app` / `chat-app` / `shop-rate` are not next to these files (pattern Java image: [`../../images/apps/java-gradle/`](../../images/apps/java-gradle/)).

**Keywords:** Java local-dev, Keycloak, Kafka, KRaft, outbox, host Postgres
