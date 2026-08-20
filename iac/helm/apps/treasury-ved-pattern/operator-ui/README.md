# Operator UI (front-base umbrella)

**Business first:** the operator console is a **thin Helm umbrella** over a shared frontend library, not a second copy of Deployment YAML. Hub: [`../../`](../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Library: [`../_libs/front-base/`](../_libs/front-base/).

I used this envelope for the estate operator SPA. The parent chart holds image, ingress, and browser env. Workload objects (Deployment, Service, Ingress, env Secret, HPA, VPA) come from `front-base` via `alias: application`.

```text
operator-ui/
  Chart.yaml                 # file://../_libs/front-base, alias application
  values.yaml                # image, ingress, browser env (placeholders)
  templates/_helpers.tpl     # unused overlay helpers (labels if a template is added)
  .gitignore                 # charts/ and Chart.lock stay out
../_libs/front-base/         # one shared frontend chart (this kit owns it)
```

Fetch the library from this directory:

```bash
helm dependency update
helm template operator-ui . --namespace estate
```

A sibling backend umbrella (`estate-auth`) uses the same shape with `base-chart` instead of `front-base`.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Thin umbrella | Chart.yaml + values + helpers. No local Deployment |
| `file://` library | One `front-base` under `_libs/`. Other UI clones stay out |
| Alias `application` | Parent keys nest under `application:` and map onto the subchart |
| `globalInherit` | Parent `global.env` is base64-packed into the same env Secret as `application.env` |
| Ingress rewrite | nginx `/(.*)` plus `rewrite-target: /$1`, TLS secret name only |
| Browser wiring | Keycloak, HTTP API, websocket, KYT links, object-storage URL as values, not a second chart |

## What this chart is not

This is not a second frontend fork. Another SPA in the same estate used the same `front-base` templates after LF. I kept one SAMPLE.

I did not copy the packaged `front-base-*.tgz`, GitLab includes, Argo Application or repo manifests, or the cluster-wide ExternalSecret merge that sat outside this repo.

## How env lands in the pod

`front-base` writes an Opaque Secret (`<fullname>-env`) through an `envify` helper: nested maps flatten to dotted keys, values are base64. The container uses `envFrom.secretRef`. Live stands also merged Vault keys through External Secrets at the estate layer. That merge YAML is not in this folder. Values here use `CHANGE_ME` and `*.example.com`.

Container listen port in the library is **8888**. Service port is **80**.

## Sanitize

Hosts are `*.example.com`. Image is `example.registry/estate/operator-ui`. Contact fields and the UI salt are placeholders. Pull-secret names stay as generic Kubernetes Secret names (`regcred`).

**Keywords:** Helm umbrella, front-base, file:// dependency, nginx Ingress, Keycloak, websocket, SPA
