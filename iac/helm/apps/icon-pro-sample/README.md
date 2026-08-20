# Shop gateway + Keycloak (Helm sample)

**Business first:** a shop estate is **one `.helm` shape**, not a 27-chart farm. I published **shop-gateway** (path-based publication Ingress) and **shop-keycloak** (realm ConfigMap plus NodePort). The other 25+ services and both CD trees stay out.

This is the in-tree Keycloak, not the estate overlay. The overlay (vendor pin + ExternalSecret, no realm dump) is [`../treasury-keycloak/`](../treasury-keycloak/). Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Truststore and pull-secret files stay out; the pattern is NOTES in [`../../reference/helm-data-plane/`](../../reference/helm-data-plane/).

```text
icon-pro-sample/
  README.md
  gateway/.helm/                 # shop-gateway
    Chart.yaml
    values.yaml                  # plus 9 stand overlays
    templates/
      publication.yaml           # path fan-out Ingress
      publication-redirect.yaml
      publication-redirect-line.yaml
      deployment.yaml            # shared backend template
      hpa.yaml
      ...                        # Service, Route, VirtualService, ServiceMonitor
  keycloak/.helm/                # shop-keycloak
    Chart.yaml
    values.yaml                  # plus 10 stand overlays (includes prod)
    dev/realm-export.json        # stub realm (no users, no client secrets)
    templates/
      configmap.yaml             # .Files.Get {{ contour }}/realm-export.json
      nodeport.yaml
      deployment.yaml
      _pod.tpl                   # unused fluent-bit leftover
      ...
```

```bash
helm template shop-gateway ./gateway/.helm \
  -f ./gateway/.helm/values.yaml \
  -f ./gateway/.helm/values-dev.yaml

helm template shop-keycloak ./keycloak/.helm \
  -f ./keycloak/.helm/values.yaml \
  -f ./keycloak/.helm/values-dev.yaml
```

## Who this page is for

Hiring lead: two charts explain a 27-service shop. Engineer: the unique files are the publication Ingress and the Keycloak realm ConfigMap / NodePort. Everything else is the shared backend template.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Full `.helm` | Chart.yaml + values overlays + templates. This family did not use a `base-chart` umbrella |
| One helpers file | `_helpers.tpl` is byte-identical in both charts. I kept a copy in each tree because Helm loads templates locally |
| shop-gateway publication | One Ingress fans paths to sibling Services (landing, front, mobile, Keycloak `/realms`, monolith). Two redirect Ingresses sit next to it |
| Multi-stand overlays | `values-dev.yaml` … `values-dev4.yaml`, `values-test*.yaml`, `values-demo.yaml`. Domain is `*.example.com` |
| shop-keycloak | Official `quay.io/keycloak/keycloak:20.0.2`, Postgres JDBC in values, `--import-realm`, NodePort, realm via ConfigMap |
| Truststore mounts | Three `cacerts` mount paths in values. The binary ConfigMap is not in git |

## Shared `_helpers.tpl`

The file is the same 93-line helpers block in `gateway/.helm/templates/_helpers.tpl` and `keycloak/.helm/templates/_helpers.tpl` (`name`, `fullname`, `labels`, `selectorLabels`, `serviceAccountName`, multi-port helpers, `podAnnotations`). I did not extract a third library copy. Other backends in that estate used this same file. There is no second helpers design.

## shop-gateway

Chart name `shop-gateway` 1.0.0. Image `example.registry/shop/gateway:main`. HPA is on (`ContainerResource` CPU/memory). Publication Ingress is always rendered (not behind `ingress.enabled`). The generic `ingress.yaml` / OpenShift `route.yaml` / Istio `VirtualService` stay off in the sample values.

`templates/configmap.yaml` is empty. The source tree also held a live realm dump under `dev/` that nothing loaded. I dropped that file.

`templates/deployment.yaml` is the shared backend template, including hardcoded Keycloak `start` args. The unique gateway work is the three publication Ingress files, not a custom Deployment.

## shop-keycloak

Chart name `shop-keycloak` 1.0.0. Image `quay.io/keycloak/keycloak:20.0.2`. `templates/configmap.yaml` does `.Files.Get` on `{{ .Values.contour }}/realm-export.json` (sample `contour: dev`). `dev/realm-export.json` is a stub realm `shop` with one public client `shop-gateway`, empty `users`, no secrets.

NodePort Service `shop-keycloak-nodeport` selects `app.kubernetes.io/name=shop-keycloak` and `app.kubernetes.io/instance=shop-keycloak`. Release name should match that instance label.

`_pod.tpl` defines `fluent-bit.pod` and is not included by any template. I left it as the source leftover.

Values still mount ConfigMap `truststore` at the JVM `cacerts` paths. I did not copy the binary CA. Pull-secret is commented only (`# imagePullSecrets`).

Stand overlays carry JDBC and admin keys. Passwords are `CHANGE_ME`. Hosts are `10.10.0.10` / `10.10.0.11`.

## NOTES (not copied)

| Source | Why it stays out |
|--------|------------------|
| The other 25+ shop services | Same helpers, same Deployment template. Copy-paste, not a second mechanic |
| Both CD trees | Thinner snapshots of the same charts |
| `deleted-*` trees | Dead checkouts |
| jsm | Infra, not this sample |
| pull-secret | Secret material. Pattern is the commented `imagePullSecrets` block |
| truststore binary `cacerts` | Binary CA. Mount paths stay in values |
| Live `realm-export.json` | Users, emails, client secrets. Replaced by the stub |
| App source (`src/`, Gradle, Dockerfile) | Not the chart |

## Pin

| Chart | Image | Shape |
|-------|-------|-------|
| shop-gateway | `example.registry/shop/gateway:main` | Deployment + Service + HPA + publication Ingress |
| shop-keycloak | `quay.io/keycloak/keycloak:20.0.2` | Deployment + ClusterIP + NodePort + realm ConfigMap |

Keycloak start flags in the Deployment: `--db postgres`, `--proxy edge`, `--http-enabled true`, `--import-realm`.

## Sanitize

[`../../SANITIZE.md`](../../SANITIZE.md). Hosts are `*.example.com`. Registry is `example.registry`. Ingress allow-list is `203.0.113.0/24`. JDBC uses documentation IPs. Passwords and the live realm dump are out. Brand service names in the publication Ingress are `shop-*`.

**Keywords:** Helm, `.helm`, API gateway, path-based Ingress, Keycloak, realm ConfigMap, NodePort, HPA, shop sample
