# Estate monolith overlay (Helm)

**Business first:** a DEMO stand can still be **one chart** with extra Services and CRs, even after the estate splits into umbrellas. Buyer page: [`../../../../../docs/for-business.md`](../../../../../docs/for-business.md). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this as the vendor-shaped monolith on a lab cluster. Later I split the same product into per-service umbrellas (`base-chart` / `front-base`). What I keep here is the overlay that the split charts do not own: extra gRPC and websocket Services, a Zalando `postgresql` CR, and Strimzi Kafka / Connect / Connector templates. Six vendor tarballs stay documented in [`NOTES.md`](NOTES.md).

```text
estate-monolith/
  Chart.yaml                 # estate-monolith; six vendor pins, five app aliases
  values.yaml                # defaults, overlay off
  values.example.yaml        # DEMO stand excerpt
  NOTES.md                   # tarball pins
  templates/
    grpc-services.yaml       # four ClusterIP Services on :6865
    websocket-services.yaml  # one ClusterIP Service on :443
    postgres.yaml            # Zalando CR + optional pooler LoadBalancer
    kafka.yaml               # Strimzi Kafka CR (off on the DEMO stand)
    kafka-user.yaml
    kafka-connect.yaml       # KafkaConnect + JMX ConfigMap
    kafka-connector.yaml
    kafka-metrics-cm.yaml
    kafka-pod-monitor.yaml
    _helpers.tpl
```

gRPC and websocket Services always render. They select `app.kubernetes.io/name` on the aliased workloads. Kafka, Connect, and Postgres stay behind values flags.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Monolith overlay | One parent, extra Services, plus CRs. Not an 18-service values dump |
| gRPC :6865 | Four ClusterIP Services next to HTTP. Same port the contract sibling uses |
| websocket :443 | Extra Service in front of `estate-web-ws` |
| Zalando Postgres | In-cluster operator CR with `wal_level: logical` for CDC |
| Bitnami kafka pin | DEMO stand broker was in-cluster. Production estate used managed DMS |
| Strimzi Connect | Same `KafkaConnect` + outbox `KafkaConnector` list as the estate Kafka kit |
| Vendor boundary | Six `.tgz` files stay out. Pins live in Chart.yaml and NOTES |

## How this differs from the estate kits

The production Kafka kit ([`../../../reference/helm-estate-cluster/kafka/`](../../../reference/helm-estate-cluster/kafka/)) talks to an external broker. This SAMPLE enabled the Bitnami `kafka` subchart on the DEMO stand and pointed Connect at that bootstrap. The Strimzi `Kafka` CR (`kafkaHA`) stayed off. I still keep the template so the overlay is complete.

Zalando Postgres matches the DEMO slice in [`../../../reference/helm-estate-cluster/postgresql/`](../../../reference/helm-estate-cluster/postgresql/). Production Postgres on the estate was managed RDS.

Keycloak and Vault are pins only. The Keycloak overlay lives in [`../../treasury-keycloak/`](../../treasury-keycloak/). Shared `base-chart` / `front-base` are `file://../_libs/...`. I did not vendor a second copy.

## Render

```bash
helm dependency build
helm template estate-demo . -f values.example.yaml
```

`helm dependency build` needs the sibling libs under `../_libs/` and network access for kafka, akhq, vault, and keycloak. Overlay templates (gRPC, websocket, Postgres, Connect) render without those fetches when the matching flags stay as in `values.example.yaml` and the Bitnami / AKHQ conditions are accepted as missing deps, or when those flags are flipped off for a local check.

A values-only check of the custom templates:

```bash
helm template estate-demo . \
  --set kafka.enabled=false \
  --set akhq.enabled=false \
  --set vault.enabled=false \
  --set keycloak.enabled=false \
  -f values.example.yaml
```

## Sanitize

Hosts are `*.example.com`. Registries are `example.registry`. Passwords and bcrypt hashes are `CHANGE_ME`. SMT class is `com.example.outbox...`. Connector list is two items, not seven copies of one password.

**Keywords:** Helm overlay, monolith, gRPC Service, websocket, Zalando Postgres, Strimzi, Kafka Connect, Debezium outbox, Bitnami Kafka pin
