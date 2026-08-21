# Jaeger (OTLP all-in-one)

**Business first:** local traces are **one Jaeger container with OTLP on**, not a vendor collector farm. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this file when a shop service needed a laptop trace sink. Ports 4318 (OTLP HTTP) and 16686 (UI). The compose still mounts `./configs/otel-config.yml`. That file was never next to the compose in the source tree.

```text
jaeger/
  docker-compose.yml    # jaegertracing/all-in-one:latest, OTLP, missing otel-config bind
```

```bash
# from this directory. the otel-config bind fails until that file exists:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `COLLECTOR_OTLP_ENABLED` | Shop apps speak OTLP, not the old Jaeger UDP ports only |
| UI `16686` | Laptop browser, not an in-cluster query service |

## Honest gap

`./configs/otel-config.yml` is **not** in this folder. A naive `docker compose up` fails on the volume. I did not invent an OTEL config.

**Keywords:** Jaeger, OTLP, 4318, all-in-one
