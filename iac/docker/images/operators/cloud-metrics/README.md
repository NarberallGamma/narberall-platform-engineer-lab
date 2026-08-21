# CloudEye metrics exporter (Dockerfile only)

**Business first:** managed RDS, Redis, and Kafka should page in the same Grafana as node-exporter. I wrapped the upstream Huawei CloudEye exporter so CES metrics for SYS.RDS / SYS.DCS / SYS.DMS land next to the estate overlay.

Helm chart that consumes the image: [`../../../../helm/reference/helm-estate-cluster/monitoring/exporters/prometheus-cloudeye-exporter/`](../../../../helm/reference/helm-estate-cluster/monitoring/exporters/prometheus-cloudeye-exporter/). Overlay: [`../../../../helm/reference/helm-estate-cluster/monitoring/`](../../../../helm/reference/helm-estate-cluster/monitoring/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

```text
cloud-metrics/
  Dockerfile              # golang:1.19-alpine → alpine:3.18, port 8087
  clouds.yml.example      # IAM placeholders
  .dockerignore
```

## Honest gap

The Go `src/` tree is **not** in this lab. It is the upstream [huaweicloud/cloudeye-exporter](https://github.com/huaweicloud/cloudeye-exporter) fork (100+ files). The Dockerfile `COPY`s `src/main.go`, `src/collector/`, `src/logs/`, and the YAML/JSON next to them. A build needs that tree placed as `src/` first.

Owner patches that lived on the private fork (RMS skip for a region the Huawei SDK does not list, instance-id filters when RMS is absent) are **not** replayed here. They are a note, not a second vendor dump.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Multi-stage pin | Go 1.19 static binary, non-root UID 1000, `CMD -config=/etc/cloudeye/clouds.yml`. |
| Scrape contract | Prometheus asks `GET /metrics?services=SYS.RDS,SYS.DCS,SYS.DMS`. The image does not hard-code one service. |
| Example auth | `clouds.yml.example` uses `iam.example.com` and `CHANGE_ME`-style fields. |

```bash
# place upstream src/ next to this Dockerfile, then:
docker build -t example.registry/estate/base-images/cloudeye-exporter:latest .
```

Without `src/` the build fails on the first `COPY`. That is expected.
