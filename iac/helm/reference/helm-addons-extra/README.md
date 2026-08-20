# Extra addons (Helm)

**Business first:** logging, object storage, quality gates, BaaS, and backup are **charts I stood up**, not a marketplace list. Hub: [`../../`](../../).

One richest tree per addon. Product samples (one richest copy per mechanic) live under [`../../apps/`](../../apps/).

```text
helm-addons-extra/
  minio-operator/
  opentelemetry-collector/
  elk/
  elasticsearch-operator/
  custom-prometheus-rules/
  elastalert2/              # ElastAlert2 + Falco
  sonarqube/
  supabase/
  openvpn-admin/
  backup-werf/              # werf-raw Borg-class backup (no Chart.yaml)
  dagster-overlay/          # Chart.yaml + values + certificate overlay only
```

## What hiring should see

| Slice | Why it is unique here |
|-------|------------------------|
| MinIO operator | Richest operator install (not the thinner data-plane contrast) |
| OTel collector | Only OpenTelemetry chart in this lab |
| ELK + ECK operator | Logging stack and a separate operator install |
| PromRule pack | Wide recording/alerting rules I maintained |
| ElastAlert2 + Falco | Runtime **log** alerts. Host EDR metrics stay in Ansible `sec-stack` |
| SonarQube | Gate I stood up from zero (same story as the root README) |
| Supabase | Only BaaS chart |
| OpenVPN admin | Staff VPN admin UI as a chart, not a public evasion how-to |
| werf backup | Borg-class backup without Chart.yaml (werf-raw) |
| Dagster overlay | Values + cert/OIDC overlay. Vendor `charts/` (100+ files) stay out |

Observability slices (PromRules, ElastAlert2, OTel, ELK/ECK) are the **API surface** I used for log and PromQL views. Host VictoriaMetrics stays in Ansible. Same-day edits: [`../../../../architecture/05-sre.md`](../../../../architecture/05-sre.md), [`../../../../docs/sre/`](../../../../docs/sre/).

**Keywords:** MinIO, OpenTelemetry, ELK, ECK, PrometheusRules, ElastAlert2, Falco, SonarQube, Supabase, OpenVPN, Borg, werf, Dagster, Grafana API
