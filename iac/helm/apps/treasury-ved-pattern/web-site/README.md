# Static site (Helm overlay)

**Business first:** the public site is a **remote Helm repo** pin plus a static nginx image, not a second `file://` `base-chart`. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Sibling websocket worker: [`../web-ws/`](../web-ws/).

I published Chart.yaml, values, helpers, and the nginx site config the image runs. I did not vendor a `base-chart` tarball. The dependency is `https://charts.example.com` with a caret range `^0.2.1`, alias `application`. That is the contrast with [`../web-ws/`](../web-ws/), which points at the shared local lib.

```text
web-site/
  Chart.yaml                      # base-chart ^0.2.1 from https://charts.example.com
  values.yaml                     # static nginx image, /health, two hosts
  .helmignore
  .gitignore                      # charts/ and Chart.lock stay out
  nginx.conf                      # image config, not a Helm template
  templates/
    _helpers.tpl
  README.md
```

Render (after `helm dependency build` against the pinned repo):

```bash
helm dependency build
helm template estate . --namespace estate
```

`helm dependency build` needs network access to `https://charts.example.com`. A downloaded `charts/base-chart-*.tgz` stays out of git.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Remote repo | Same `base-chart` name as the local lib, different delivery. Range `^0.2.1`, not `file://` |
| Static nginx | Port 80, probes on `/health`, two hosts, ACME TLS |
| nginx.conf | gzip, long cache on assets, SPA fallback, hidden-file deny. Baked into the image |
| Thin overlay | No extra Service, no ExternalSecret, no initContainers |

## Dependency (documented, not vendored)

| Chart | Pin | Repository | In git |
|-------|-----|------------|--------|
| base-chart | ^0.2.1 | `https://charts.example.com` | overlay only |

The live chart used a private Helm repository. The public pin is the example host. I do not copy the remote chart tree.

## Sanitize

Hosts are `site.example.com` and `www.site.example.com`. Image is `example.registry/platform/web-site:2.0`. Chart `appVersion` stays `1.0` because that is what the umbrella declared. HTML, logos, and the branded Dockerfile stay out. Namespace and `fullnameOverride` are `estate`.

**Keywords:** Helm overlay, remote Helm repo, static nginx, base-chart, ingress
