# NiFi (Helm)

**Business first:** document and integration flows next to the shop, as a chart, not a laptop compose. Parent kit: [`../`](../).

PROD tree (richest). Chart flattened from `.helm/` so `helm template` runs at this directory. Image pin `apache/nifi:2.6.0`. No vendor Helm tree.

## Copied (11 files)

| Path | Role |
|------|------|
| `Chart.yaml` | Chart name `nifi`, app 2.6.0 |
| `values.yaml` | Default host, user, `CHANGE_ME` password, PVC size |
| `values-prod.yaml` | Prod host overlay |
| `values-preprod.yaml` | Preprod host overlay |
| `values-dev.yaml` | Dev host overlay |
| `templates/deployment.yaml` | Recreate, uid 1000, five repo subPaths on one PVC |
| `templates/service.yaml` | HTTPS 8443 |
| `templates/pvc.yaml` | Size from values, storage class placeholder |
| `templates/ingress.yaml` | nginx, backend HTTPS, TLS secret from values |
| `start-prod.sh` | `helm upgrade -i` helper |
| this README | Copy vs NOTES |

`helm template nifi . -f values-prod.yaml` renders Deployment, Service, PVC, Ingress.

## NOTES (not copied)

| Source | Why it stays out |
|--------|------------------|
| Upstream Apache NiFi Helm chart | Never vendored. This tree is a single-user Deployment |
| `docker-compose.yml` | Not Helm. Lived next to the chart; credentials stay out |
| Thinner preprod tree | Same templates, fewer values files |
| Preprod `tls.yml` | kubernetes.io/tls Secret with cert and key bytes |
| Dev Dockerfile | Image build, not this release |
| Pull-secret / truststore files | Not present in the PROD chart; pattern is NOTES |

## Pin

| Item | Value |
|------|-------|
| Image | `apache/nifi:2.6.0` |
| Chart version | 1.0.0 |
| Auth | single-user env (`SINGLE_USER_CREDENTIALS_*`) |
| UI | HTTPS 8443 behind nginx |

## Sanitize

Hosts are `nifi.<env>.example.com`. Passwords are `CHANGE_ME`. Storage class is `example-block`. Live shop FQDNs and private registries are stripped. [`../../../SANITIZE.md`](../../../SANITIZE.md).

**Keywords:** NiFi, Ingress, PVC, single-user, document flows
