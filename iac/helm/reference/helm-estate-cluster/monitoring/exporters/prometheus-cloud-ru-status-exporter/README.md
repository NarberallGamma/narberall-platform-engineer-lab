# Prometheus Cloud.ru status exporter

Custom chart I used to scrape Cloud.ru status / emergency work into Prometheus so Grafana can page planned outages the same way as CloudEye RDS lag. Image lives in `example.registry/platform/base-images` (`cloud-ru-status-exporter:1.4`). ServiceMonitor is **on**. Port `8087`.

This is an HTTP client against the public status API (`api.cloud.ru` class), not a vendor tree. Sibling: [`../prometheus-cloudeye-exporter/`](../prometheus-cloudeye-exporter/). Overlay: [`../../`](../../). How I use those APIs: [`../../../../../../../architecture/05-sre.md`](../../../../../../../architecture/05-sre.md), [`../../../../../../../docs/sre/on-call.md`](../../../../../../../docs/sre/on-call.md).

## Install

```bash
helm upgrade --install prometheus-cloud-ru-status-exporter . \
  --namespace monitoring \
  --values values.yaml \
  --wait
```

Liveness/readiness hit `/health` on the metrics port.
