# openobserve-collector

Custom chart **0.1.2**: OpenTelemetry Collector contrib **0.138.0** as a DaemonSet. Stdout/stderr from selected namespaces go to OpenObserve. Logs only (metrics/traces off).

I do not use the OpenTelemetry Operator. The DaemonSet lives in `monitoring` and reads files on the node. App namespaces have no collector pods. CCE `log-agent-*` is left alone. Workloads in `estate-app` are not annotated or restarted.

## CCE hostPath

On this CCE build `/var/log/pods` on the host is empty. Real container stdout is:

`/var/lib/containerd/container_logs/<ns>_<pod>_<uid>/<container>/0.log`

Files are `0640`, directory `0750`, owner root. Values mount that hostPath at `/var/log/pods` inside the container. The collector runs as uid 0 so filelog can read. That pattern is documented in `values.yaml` (`hostLogs.path` / `hostLogs.mountPath`).

## Ingest

- `start_at: end`: no full-file replay on start
- Recombine: CRI `P`/`F`, then Java stacks (`at `, `Caused by:`, `Exception`, `Suppressed:`) into one `body` (`overwrite_with: oldest`)
- Exclude the collector itself, OpenObserve ingester, and CCE `log-agent`

Endpoint in values is `http://openobserve-router.monitoring.svc.cluster.local:5080/api/CHANGE_ME`. Org id is a placeholder. Auth: HTTP Basic, user `otel-collector@example.com`. Password comes from ESO (`ZO_MAIN_SERVICE_ACCOUNT_TOKEN`); no token in git.

## Namespaces

| Namespace | Stream | Group |
|-----------|--------|-------|
| estate-app | `ns_estate_app` | app |
| kafka | `ns_kafka` | infra |
| istio-system | `ns_istio_system` | infra |
| ingress-nginx | `ns_ingress_nginx` | infra |
| external-secret-manager | `ns_external_secret_manager` | infra |
| argocd | `ns_argocd` | infra |
| monitoring | `ns_monitoring` | infra |

Each record: `k8s_app`, `k8s_namespace`, `k8s_pod`, `k8s_container`, `k8s_node`, `service_name`, `log_group`, `o2_stream`, `k8s_cluster`, `environment`. Filter on **`k8s_app`**.

```bash
# from this chart directory:
helm upgrade --install openobserve-collector ./ \
  --namespace monitoring \
  --values values.yaml
```
