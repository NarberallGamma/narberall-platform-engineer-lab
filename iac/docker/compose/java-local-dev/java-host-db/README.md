# Shop-rate against host Postgres

**Business first:** some shop services keep Postgres **on the host** and only put the JVM in Docker. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Combined image: [`../../../images/apps/java-gradle/`](../../../images/apps/java-gradle/).

I used this 14-line file when the rate service talked to a local cluster on `host.docker.internal:5432`. The service, image, container, and JDBC database are named `shop-rate` / `shop_rate`.

```text
java-host-db/
  docker-compose.yml    # shop-rate:latest, build ., JDBC host.docker.internal/shop_rate
```

```bash
# from this directory, after a Gradle tree and a host DB shop_rate exist:
docker compose up --build
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `host.docker.internal` | The container is not the database |
| `build: context: .` | Image is the service next to this file |
| JDWP `5005` | Same attach port as the other Java stacks |

## Honest gap

App source and `Dockerfile` are **not** in this folder. `docker compose up --build` fails until a Gradle tree is the context. Host Postgres and database `shop_rate` are not created here.

**Keywords:** host.docker.internal, shop-rate, shop_rate, JDWP
