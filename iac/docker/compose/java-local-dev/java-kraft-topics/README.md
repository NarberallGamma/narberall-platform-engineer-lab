# KRaft broker + topic bootstrap

**Business first:** local order-info streams need **KRaft with auto-create off** and a one-shot topic list, or e2e DLQ tests lie. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). ZK laptop broker: [`../../dev-deps/kafka/`](../../dev-deps/kafka/).

I used this file for order-info plus shop streams. `PLAINTEXT_HOST` advertises `localhost:9092` for a Spring local profile. In-compose clients use `kafka:29092`. `CLUSTER_ID` is the public Confluent example. The header still marks the stack as needing follow-up work.

```text
java-kraft-topics/
  docker-compose.yml    # cp-kafka:7.7.5 KRaft, auto.create=false, bootstrap job
```

```bash
# from this directory:
docker compose up -d
# kafka-topics-bootstrap exits after creating topics (restart: no)
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| KRaft (no ZooKeeper) | Different mechanic from [`../../dev-deps/kafka/`](../../dev-deps/kafka/) |
| `AUTO_CREATE_TOPICS_ENABLE=false` | Deleting an external topic must stay deleted so DLQ e2e works |
| Bootstrap container | Creates shop/order/agreement/audit and Streams changelog topics once |
| Dual host ports | `9092` and `29092` both map to the host listener |

## Honest gap

The source file is marked as still needing work. Topic names are the shop test set, not a generic `demo`. No Kafka UI. No app service.

**Keywords:** KRaft, 7.7.5, topic bootstrap, auto.create off, DLQ
