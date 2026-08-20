# ElastAlert2 and Falco (Helm)

**Business first:** runtime **log** alerts on Elasticsearch, not host metrics. I add and edit ElastAlert / Kibana views through the ES HTTP API the same way I edit Grafana panels. Hub: [`../`](../). Manager page: [`../../../../../architecture/05-sre.md`](../../../../../architecture/05-sre.md). Catalog: [`../../../../../docs/sre/logs-traces.md`](../../../../../docs/sre/logs-traces.md). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I ran ElastAlert 2 (chart/app 2.20.0) as a werf Helm install. Rules are files under `.helm/rules/`, selected per environment in `enabledRules`. Falco lives **inside this tree** (`.helm/rules/falco/`), not a sibling chart: the same ElastAlert process watches `falco-*` indices for shell-in-container.

This is complementary to Ansible host metrics. EDR / PAN-OS exporters and VictoriaMetrics stay in [`sec-stack`](../../../../ansible/reference/ansible-llm-collab/extras/sec-stack/). Do not merge the two.

```text
elastalert2/
  werf.yaml
  .gitlab-ci.yml
  .helm/
    Chart.yaml                 # elastalert2 2.20.0
    values.yaml                # enabledRules per env; ES host is a placeholder
    templates/                 # deploy, config, rules ConfigMap, smtp-auth
    rules/
      10_* / 30_* / 32_* / 50_*   # Suricata alert.action:blocked (dev/prod/prod2/shop)
      80_app_logs_monitoring.yaml
      falco/                     # Falco shell-in-container, four envs
  examples/                    # upstream ElastAlert 2 samples
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Multi-env `enabledRules` | Dev / production / production-use1 / production2 pick different rule files. Four `*_test_notif` YAML files sit on disk and stay **out** of `enabledRules` (Slack / Telegram smoke tests, not on-call) |
| Suricata rules | Frequency alerts on `alert.action:blocked` with geo and signature fields |
| Falco rules | `type: any` on `data.rule.keyword: run_shell_in_container`, index `falco-*` |
| App log rule | ERROR/CRITICAL/FATAL on a filebeat-style index (UUID is a fake) |
| Slack / Telegram | Channel names stay; webhook and bot token are `CHANGE_ME` |
| SMTP template | `smtp-auth.yaml` can mount a Secret. Values stay commented `CHANGE_ME` |

## Observability split

| Layer | Where | What |
|-------|-------|------|
| Log runtime alerts | this chart | ElastAlert2 + Falco on Elasticsearch |
| Host / cybersec metrics | Ansible `sec-stack` | VictoriaMetrics, Grafana, vmalert, PAN-OS / EDR exporters |

## Sanitize

Slack webhooks, Telegram bot token/room, SMTP user/password, and live ES service names are placeholders (`elasticsearch.logging.svc`, `CHANGE_ME`). Tenant rule names are generic (`shop`).

**Keywords:** ElastAlert2, Falco, Suricata, Elasticsearch, Helm, werf, Slack, Telegram
