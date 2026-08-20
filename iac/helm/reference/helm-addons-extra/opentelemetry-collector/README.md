# OpenTelemetry collector

**Business first:** app logs leave the cluster as **OTLP in, Kafka out**, after a transform that drops everything except an admin path. Hub: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

This is the only OpenTelemetry chart in the dump-derived lab. The source was werf-raw (no Chart.yaml). I added a thin Chart.yaml so the overlay is a readable chart. The unique piece is one `OpenTelemetryCollector` CR (`opentelemetry.io/v1beta1`).

```text
opentelemetry-collector/
  Chart.yaml
  values.yaml                # brokers, filter path, Deckhouse system-node placement
  werf.yaml                  # project pin only (no app image)
  templates/
    collector.yaml           # OpenTelemetryCollector CR
```

Requires the OpenTelemetry Operator CRDs on the cluster (not vendored here).

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Collector CR | Deployment mode, 2 replicas, OTLP gRPC/HTTP |
| Kafka exporter | Brokers and topic come from values, keyed by `werf.env` |
| Transform | ParseJSON, keep a short key list, delete records that are not the admin path |
| Placement | Deckhouse system-node selector and toleration |

## Vendor chart (documented, not vendored)

| Chart | Pin | What I changed | In git |
|-------|-----|----------------|--------|
| OpenTelemetry Operator | CRD `v1beta1` (cluster install) | Collector spec only | overlay CR |

## Sanitize

Brokers are `kafka-bootstrap.{lab,production}.svc.cluster.local`. Filter path is `/admin`. Live env names and product paths are placeholders.

**Keywords:** OpenTelemetry, OTLP, Kafka, transform, Deckhouse, werf
