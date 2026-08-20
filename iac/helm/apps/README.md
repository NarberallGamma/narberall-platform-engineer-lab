# Helm apps

**Business first:** a product release is **one richest chart per mechanic**, not a thirty-service farm. Buyer page: [`../../../docs/for-business.md`](../../../docs/for-business.md). Case: [`../../../case-studies/11-helm-estate.md`](../../../case-studies/11-helm-estate.md). Cluster envelope stays in [`../reference/helm-estate-cluster/`](../reference/helm-estate-cluster/).

I publish curated samples here. Cluster mesh, CDC, secrets bootstrap, GitOps door, and observability overlays live under [`../reference/`](../reference/). Hunters looking for microservices should start on this page, not inside a Kafka Connect chart.

Honest scope: one richest copy per mechanic. This is not thirty-seven estate services, not twenty-seven shop backends, and not a forty-unit werf monorepo. Living trees are in the listed folders.

Hub: [`../`](../). Sanitize: [`../SANITIZE.md`](../SANITIZE.md).

```text
apps/
  treasury-keycloak/           # MUST Keycloak overlay (codecentric 17.0.2)
  treasury-ved-pattern/        # estate product mechanics + shared libs
    _libs/base-chart/
    _libs/front-base/
    estate-auth/
    operator-ui/
    policy-gateway/
    pki-gateway/
    cryptopro/
    contract-grpc/
    web-ws/
    web-site/
    estate-monolith/
    integration-secret/
  icon-pro-sample/             # two .helm trees (gateway + keycloak)
  helmfile-dev/                # two DEV helmfiles + local charts
  werf-raw/                    # werf + .helm/, no Chart.yaml
  chart-flant-lib/             # Chart.yaml + HTTPS flant-lib
  chart-local-subchart/        # Chart.yaml + local subchart
  oci-common-app/              # Chart.yaml + OCI common library
  werf-monorepo-sample/        # shared werf values + one unit
```

## Who this page is for

| Reader | What to take | Then open |
|--------|----------------|-----------|
| Hiring lead | Product Helm is umbrellas, overlays, and packaging variants. I do not paste a vendor Keycloak tree or a 30-shop CCE dump | [`treasury-keycloak/`](treasury-keycloak/), [case 11](../../../case-studies/11-helm-estate.md) |
| Engineer | Each folder is one mechanic. Shared `base-chart` / `front-base` live once under `_libs/` | Table below |
| Founder / PM | Apps wait on the Argo door. The door is bootstrap in the estate kit, not Application lists | [`../reference/helm-estate-cluster/argocd/`](../reference/helm-estate-cluster/argocd/) |

## What hiring should see

| Slice | Mechanic | Why one copy is enough |
|-------|----------|------------------------|
| [`treasury-keycloak/`](treasury-keycloak/) | **MUST overlay.** Parent Chart.yaml, values, ExternalSecret. Vendor pin is **codecentric keycloak 17.0.2** plus unused Bitnami PostgreSQL **10.3.13** under that tree. Not Bitnami Keycloak | The 84-file `charts/keycloak/` tree stays a NOTES pin. Postgres is managed. Overlay already lives in that folder |
| [`treasury-ved-pattern/estate-auth/`](treasury-ved-pattern/estate-auth/) | Thin umbrella + ExternalSecret + `file://` [`_libs/base-chart/`](treasury-ved-pattern/_libs/base-chart/) | Canon estate backend. Siblings reuse the same library |
| [`treasury-ved-pattern/operator-ui/`](treasury-ved-pattern/operator-ui/) | Thin umbrella + `file://` [`_libs/front-base/`](treasury-ved-pattern/_libs/front-base/) | Canon estate frontend. A second SPA used the same templates |
| [`treasury-ved-pattern/policy-gateway/`](treasury-ved-pattern/policy-gateway/) | CryptoPro: one PVC (lookup/keep) + initContainers + bootstrap | Richest CryptoPro of the three |
| [`treasury-ved-pattern/pki-gateway/`](treasury-ved-pattern/pki-gateway/) | CryptoPro: three PVCs + ConfigMap via `.Files.Get` | Not a subset of policy. Different volume and file wiring |
| [`treasury-ved-pattern/cryptopro/`](treasury-ved-pattern/cryptopro/) | Thin CryptoPro PVC + keep, no bootstrap | Contrast only |
| [`treasury-ved-pattern/contract-grpc/`](treasury-ved-pattern/contract-grpc/) | Extra ClusterIP Service on :6865 next to HTTP | Same port other adapters used. One SAMPLE |
| [`treasury-ved-pattern/web-ws/`](treasury-ved-pattern/web-ws/) | Kafka truststore `initContainers` in values | CA is a runtime Secret. No binary truststore in git |
| [`treasury-ved-pattern/web-site/`](treasury-ved-pattern/web-site/) | Remote Helm repo pin + static nginx | Contrast with `file://` umbrellas |
| [`treasury-ved-pattern/estate-monolith/`](treasury-ved-pattern/estate-monolith/) | DEMO overlay: extra gRPC/WS Services, Zalando, Kafka Connect templates | Six vendor `.tgz` stay out |
| [`treasury-ved-pattern/integration-secret/`](treasury-ved-pattern/integration-secret/) | Richest per-service ExternalSecret | Longer than estate-auth. Not the cluster Merge generator |
| [`icon-pro-sample/`](icon-pro-sample/) | Full `.helm` for gateway + keycloak | Shop-class helpers. Not twenty-seven backends |
| [`helmfile-dev/`](helmfile-dev/) | Two helmfiles, one DEV namespace, local charts | Only helmfile SAMPLE. Istio install stays in the mesh kit |
| [`werf-raw/`](werf-raw/) | werf + `.helm/`, no Chart.yaml | PHP webapps + SPA dashboard. Backup werf-raw is an addon |
| [`chart-flant-lib/`](chart-flant-lib/) | Chart.yaml + HTTPS flant-lib dependency | One packaging shape |
| [`chart-local-subchart/`](chart-local-subchart/) | Chart.yaml + local subchart | Other packaging shape |
| [`oci-common-app/`](oci-common-app/) | Chart.yaml + OCI `common` library | Library tarball is not in git |
| [`werf-monorepo-sample/`](werf-monorepo-sample/) | Shared werf values + one cache-proxy unit | Not forty donor/slot charts |

The nine estate mechanics sit under [`treasury-ved-pattern/`](treasury-ved-pattern/) (auth, operator UI, three CryptoPro variants, gRPC, websocket truststore, static site, monolith overlay). The integration ExternalSecret is the extra SAMPLE next to them. Shared libraries are `_libs/base-chart` and `_libs/front-base` once.

## Keycloak pin (read this once)

The estate Keycloak chart is **codecentric 17.0.2**. Bitnami appears only as the PostgreSQL subchart **10.3.13**, and that subchart stays off (`postgresql.enabled: false`). I do not publish Bitnami Keycloak. I do not copy `charts/keycloak/`. `helm dependency build` is meant to pull 17.0.2 from the codecentric index. The overlay is [`treasury-keycloak/`](treasury-keycloak/).

Shop-class Keycloak under [`icon-pro-sample/keycloak/`](icon-pro-sample/) is a different packaging (full `.helm`). It is not the estate overlay.

## What this folder is not

- Not thirty product umbrellas on CCE
- Not Argo `Application` lists or repository secrets
- Not vendor tarballs (codecentric Keycloak, Bitnami Kafka/Keycloak, AKHQ, Vault, Strimzi CRD trees)
- Not twenty-six estate clones that only change ExternalSecret keys
- Not blockchain node charts (portfolio blockchain is Istio egress + ExternalSecret in the estate kit)

**Keywords:** Helm, umbrella, overlay, Keycloak, codecentric, External Secrets, base-chart, front-base, CryptoPro, gRPC, helmfile, werf, OCI Helm
