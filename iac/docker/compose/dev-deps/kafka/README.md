# Kafka + ZooKeeper (laptop)

**Business first:** a shop DEV broker on the laptop is **ZooKeeper plus one Kafka**, advertised on `localhost:29092`. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). KRaft + topics: [`../../java-local-dev/java-kraft-topics/`](../../java-local-dev/java-kraft-topics/).

I used this file when a service only needed a broker, not topic bootstrap or kafka-ui. Images are `confluentinc/cp-*:latest` (unpinned, as in the source).

```text
kafka/
  docker-compose.yml    # ZK 22181, Kafka 29092, PLAINTEXT + PLAINTEXT_HOST
```

```bash
# from this directory:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Two listeners | In-compose `kafka:9092`, host `localhost:29092` |
| Replication factor 1 | Single-node DEV |

## Honest gap

No topic list, no UI, no KRaft. `latest` tags are the real file, not a tutorial pin. The richer broker (7.4.0 + kafka-ui) sits inside [`../../java-local-dev/java-local-stack/`](../../java-local-dev/java-local-stack/).

**Keywords:** Kafka, ZooKeeper, advertised listeners, laptop
