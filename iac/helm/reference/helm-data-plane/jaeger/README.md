# Jaeger (Helm)

**Business first:** traces for a 50-service shop, not a sidecar screenshot. Parent kit: [`../`](../).

Custom chart. Service + Deployment + Ingress. Image pin `jaegertracing/all-in-one:1.63.0`. No vendor Helm tree.

## Copied (13 files)

| Path | Role |
|------|------|
| `Chart.yaml` | Chart name `jaeger`, app 1.63.0 |
| `values.yaml` | Default replica + `public_domain` |
| `values-prod.yaml` … `values-test3.yaml` | Eight env host overlays |
| `templates/jaeger.yaml` | ClusterIP (UI 16686, OTLP HTTP 4318) + all-in-one Deployment |
| `templates/ingress.yaml` | nginx Ingress, TLS secret name `tls` |
| this README | Copy vs NOTES |

`helm template jaeger . -f values-prod.yaml` renders Service, Deployment, Ingress.

## NOTES (not copied)

| Source | Why it stays out |
|--------|------------------|
| Upstream `jaegertracing/jaeger` Helm chart | Never vendored. This tree is a thin all-in-one wrapper |
| GitLab project README | Boilerplate only |
| TLS secret `tls` | Ingress names the secret. Cert bytes stay out |

## Pin

| Item | Value |
|------|-------|
| Image | `jaegertracing/all-in-one:1.63.0` |
| Chart version | 0.1.0 |
| Collector | Zipkin HTTP 9411, OTLP HTTP 4318, UI 16686 |

## Sanitize

Ingress hosts are `jaeger.<env>.example.com`. Live shop FQDNs and any private registry are stripped. [`../../../SANITIZE.md`](../../../SANITIZE.md).

**Keywords:** Jaeger, OTLP, Zipkin, Ingress, traces
