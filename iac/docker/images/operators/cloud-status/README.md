# Cloud status exporter

**Business first:** planned work and a regional incident should page the same Grafana as RDS lag. I wrote a small Go client against the public Cloud.ru status APIs so emergency and availability land on `/metrics`.

Helm chart: [`../../../../helm/reference/helm-estate-cluster/monitoring/exporters/prometheus-cloud-ru-status-exporter/`](../../../../helm/reference/helm-estate-cluster/monitoring/exporters/prometheus-cloud-ru-status-exporter/). How those APIs are used on call: [`../../../../../architecture/05-sre.md`](../../../../../architecture/05-sre.md). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

```text
cloud-status/
  Dockerfile              # golang:1.19-alpine → alpine:3.18, port 8087
  src/
    main.go               # owner HTTP client
    go.mod
    config.yml            # platform + api_base_url
```

This is **not** a vendor dump. The source in `src/` is the whole program.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Two public APIs | `service_availability` and `emergency` on `api.cloud.ru`. Config default `/app/config.yml`, Helm overlay mounts `/etc/cloud-status/config.yml`. |
| Metrics | Availability gauge, emergency counts, event info. `/metrics`, `/health`, `/`. |
| Same port class | 8087, same shape as the CloudEye wrapper so the overlay stays consistent. |

```bash
docker build -t example.registry/estate/base-images/cloud-status-exporter:1.0 .
docker run --rm -p 8087:8087 \
  -v "$PWD/src/config.yml:/etc/cloud-status/config.yml:ro" \
  example.registry/estate/base-images/cloud-status-exporter:1.0
```

`platform` is `advanced` / `evolution` / `vmware`. Tokens are not required; the APIs are public.
