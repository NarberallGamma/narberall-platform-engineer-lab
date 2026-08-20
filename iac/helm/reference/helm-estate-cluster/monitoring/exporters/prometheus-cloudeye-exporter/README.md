# Prometheus CloudEye exporter

Custom chart I used to scrape Huawei/SberCloud CloudEye into Prometheus: RDS (SYS.RDS), DCS (SYS.DCS), DMS (SYS.DMS). Binary is the upstream [huaweicloud/cloudeye-exporter](https://github.com/huaweicloud/cloudeye-exporter) (app **1.11** / chart **1.0.3**). Image lives in `example.registry/platform/base-images`.

The exporter can list every CES metric. Prometheus chooses services with `GET /metrics?services=SYS.RDS,SYS.DCS,SYS.DMS`. ServiceMonitor is **off**: a second Prometheus via SM doubled `Collect()` and overloaded CES. Scrape is a static job on the in-cluster Prometheus (not vendored in this overlay).

## Secrets

ESO reads Vault `secret/cloudeye-exporter` (`access_key`, `secret_key`, `project_name` or `project_id`). Values keep IAM URL/region as placeholders (`iam.example.com`, `CHANGE_ME`). Instance id filters are placeholders.

IAM needs CES read plus RMS list/get so the exporter can resolve RDS/DCS/DMS resources.

## Install

```bash
helm upgrade --install prometheus-cloudeye-exporter . \
  --namespace monitoring \
  --values values.yaml \
  --wait
```

Liveness/readiness are **tcpSocket** on the metrics port. Hitting `/metrics` from a probe triggers CES and used to restart the pod.
