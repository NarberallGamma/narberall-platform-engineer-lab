# Provisioned Grafana alerts

I provision rules as one YAML per group under this folder. The Grafana chart `alerting:` map (see `../values.example.yaml`) copies each file into `/etc/grafana/provisioning/alerting/` on upgrade. Sidecar alerts are off. Between upgrades I still use the Grafana HTTP API to add or edit a view the same day, then land the YAML here. Manager page: [`../../../../../../../architecture/05-sre.md`](../../../../../../../architecture/05-sre.md). Catalog: [`../../../../../../../docs/sre/metrics.md`](../../../../../../../docs/sre/metrics.md).

## Helm `tpl`

The upstream chart wraps each `file` in `tpl(...)`. A `#` comment does **not** stop Go template parse: any `{{ ... }}` in the file is Helm. Grafana annotation templates that need `$values` are escaped as `{{ "{{" }} ... {{ "}}" }}`. Math on query refs uses `{{ printf "$" }}B` so Helm does not eat `$B`.

## Contact points

| Name | Kind |
|------|------|
| Platform Grafana Alerts | Telegram (created in UI / pre-existing; not this folder) |
| Platform Grafana Email (admins) | SMTP, `ops@example.com` |
| Platform Grafana Email (ops) | SMTP, `ops@example.com; oncall@example.com` |

SMTP host/user/password: `grafana.ini` plus ExternalSecret `grafana-smtp-vault-secrets` (Vault `secret/grafana`). Template: `../templates/external-secret-smtp.yaml`.

`notification-policies.yaml`: most dashboards Telegram (`continue: true`) then email (admins). **Estate / Databases / Global**: Telegram -> ops (`continue: true`) -> admins. **Estate / Ledger / Global**: Telegram -> admins (no ops hop). Catch-all by `alertname`. Disk rules group by `instance` + `mountpoint` so Telegram stays under 4096 characters.

## Datasource UIDs

Prometheus: `PBFA97CFB590B2093` (same as `datasources` in values). SQL rules on Estate / Databases / Global use PostgreSQL UIDs `ffjo3xgrf6yo0d` (estate_web) and `cfjv6d9key8zka` (estate_ledger_adapter). Placeholders, not live DSN.

## `noDataState` / `execErrState`

All metric-threshold rules use `OK` for both. A scrape gap or Prometheus timeout must not page. Notify only when the query returns a value and the threshold fires.

## Files

| File | What |
|------|------|
| `platform-grafana-email-contactpoint.yaml` | admins + ops email |
| `estate-ledger-global.yaml` | Ethereum / TRON lag > 100 / >= 200 |
| `estate-databases-global.yaml` | COMPLETED + token_balance; wallet_tx FATAL_ERROR. Excluded `request_id` / `bid_id` are fake UUIDs |
| `kubernetes-views-pods-resources.yaml` | CPU/memory vs limits (70% WARN, 90% CRIT) |
| `notification-templates.yaml` | `platform.message` (Telegram HTML), `platform.email.*` (plain text; `reReplaceAll`, not `replace`) |
| `notification-policies.yaml` | grouping and dual delivery |
| `cloud-ru-global-alerts.yaml` | Cloud.ru events (`event_type="Авария"` is the exporter label) |
| `kafka-dms-cloudeye.yaml` | DMS lag / broker |
| `postgresql-rds-cloudeye.yaml` | RDS |
| `strimzi-kafka-connect.yaml` | Connect pods |
| `kubernetes-cce-alerts.yaml` | CCE API / DNS / PVC |
| `node-exporter-host.yaml` | host + disk |
