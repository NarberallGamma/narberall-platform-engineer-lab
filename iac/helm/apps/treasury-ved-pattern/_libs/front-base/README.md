# front-base (shared frontend chart)

**Business first:** every estate SPA I shipped reused **one** frontend chart. This folder is that chart. Umbrella SAMPLE: [`../../operator-ui/`](../../operator-ui/). Sanitize: [`../../../../SANITIZE.md`](../../../../SANITIZE.md).

I kept Deployment, Service, Ingress, env Secret, HPA, VPA, and a helm test hook here. Product umbrellas depend on this tree with `repository: file://../_libs/front-base` and `alias: application`. They do not vendor a second copy under `charts/`.

```text
front-base/
  Chart.yaml                 # name front-base, version 0.1.1
  values.yaml                # scaffold defaults (ingress off, replica 1)
  .helmignore
  templates/
    _helpers.tpl             # names, labels, envify (nested env to b64)
    deployment.yaml          # container port 8888, envFrom Secret
    service.yaml             # ClusterIP 80 -> http
    ingress.yaml             # kube 1.14 / 1.19 api switch
    secret.yaml              # Opaque <fullname>-env
    hpa.yaml                 # autoscaling/v2beta1, off by default
    vpa.yaml                 # rendered only when .Values.vpa is set
    NOTES.txt
    tests/test-connection.yaml
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| One library | Operator UI and a second SPA shared these templates after LF. One copy |
| `envify` | Nested `global.env` / `env` maps become dotted keys in a Secret |
| `globalInherit` | Parent `global.env` is optional; the UI umbrella turns it on |
| Probes | HTTP GET `/` on port `http` (8888), timeout from values |
| emptyDir | Optional volume when `emptyDir.enabled` is true |
| HPA / VPA | HPA off by default. VPA is opt-in (`vpa:` in parent values). Default values have no `vpa` key |

## Values the umbrella overrides

The SAMPLE umbrella sets `application.image`, `application.env`, `application.ingress`, `application.resources`, and `application.globalInherit`. Library defaults stay empty so a second frontend can reuse the same chart without copying YAML.

Render from the umbrella directory after `helm dependency update`, not from this folder alone, if the goal is the estate operator wiring.

## Sanitize

No live hosts or registries in this library. Scaffold ingress host is `chart-example.local` and stays unused while `ingress.enabled` is false.

**Keywords:** Helm library, frontend, envify, Ingress, HPA, VPA, Secret
