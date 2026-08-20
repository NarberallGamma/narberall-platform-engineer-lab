# Websocket worker (Helm overlay)

**Business first:** Kafka SASL_SSL truststore is built **in values**, not as a binary CA in git. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Shared library: [`../_libs/base-chart/`](../_libs/base-chart/). Sibling static site: [`../web-site/`](../web-site/).

I published the umbrella only. Shared `base-chart` 0.2.1 is `file://../_libs/base-chart`. I did not vendor a second copy. The Kafka CA Secret is mounted at runtime. The init container copies JVM `cacerts` and imports that CA into an emptyDir JKS.

```text
web-ws/
  Chart.yaml                      # alias application -> file://../_libs/base-chart 0.2.1
  values.yaml                     # truststore initContainers, Istio, ingress, probes
  .gitignore                      # charts/ and Chart.lock stay out
  templates/
    _helpers.tpl
    external-secret.yaml          # one Vault key: kafkaClientPassword
  README.md
```

I do not ship `Chart.lock`. Fetch the library from this directory:

```bash
helm dependency update
helm template estate . --namespace estate
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Truststore in values | `initContainers` plus `extraVolumes` / `extraVolumeMounts` on the umbrella. `base-chart` already has a `global.truststore` flag. This service does not use it |
| No CA in git | Secret `kafka-ca-cert` key `ca.crt`. The JKS is built in the pod |
| ExternalSecret | One key, `kafkaClientPassword`, from `secret/estate-kafka` via ClusterSecretStore |
| Istio sidecar | Inject on, proxy 100m / 128Mi |
| Ingress | Path rewrite under `/api/v0/web-ws/`, CORS to `app.example.com` |

## How the umbrella is wired

1. Parent templates only the ExternalSecret (and unused helpers).
2. `application:` values are the subchart. Deployment, Service, Ingress, and probes live in `_libs/base-chart`.
3. `extraEnvFrom` mounts `web-ws-vault-secrets` so JAAS can read `${kafkaClientPassword}`.
4. Init container `create-truststore` writes `/tmp/kafka-truststore/kafka-truststore.jks` before the JVM starts SASL_SSL.

## Dependency (documented, not vendored here)

| Chart | Pin | Repository | In git |
|-------|-----|------------|--------|
| base-chart | 0.2.1 | `file://../_libs/base-chart` | one shared copy |

## Sanitize

Hosts are `*.example.com`. Registry is `example.registry/platform/...`. Kafka bootstrap is `kafka-N.example.com:9093`. Vault path is `secret/estate-kafka`. `changeit` is the well-known Java `cacerts` password, not a live credential. JDWP on 5005 is the pre-prod debug flag I actually shipped. Namespace and `fullnameOverride` are `estate`.

This overlay does not set nginx `proxy-read-timeout` / keepalive. Long-lived websocket timeouts lived on another stand and are not copied here.

**Keywords:** Helm overlay, Kafka SASL_SSL, JKS truststore, initContainers, External Secrets, Istio, websocket
