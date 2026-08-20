# Estate auth (umbrella)

**Business first:** a product service is a **thin umbrella**, a **shared base chart**, and an **ExternalSecret**. Values stay in git. Passwords do not.

This is the canon SAMPLE for the estate product line: parent `Chart.yaml` plus values plus one ExternalSecret, with `base-chart` pulled as `file://../_libs/base-chart` (alias `application`). Sibling umbrellas (policy, PKI, CryptoPro, gRPC, websocket, integration secret) reuse that same library. They do not vendor a second copy.

Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Shared library: [`../_libs/base-chart/`](../_libs/base-chart/).

```text
estate-auth/
  Chart.yaml                      # umbrella; file://../_libs/base-chart
  values.yaml                     # Istio inject, Kafka truststore init, ingress, probes
  templates/
    external-secret.yaml          # Vault keys for Kafka, Postgres, JWT
    _helpers.tpl                  # parent labels (unused by the subchart)
```

I do not ship `Chart.lock`. Run `helm dependency update` from this directory so Helm records the local library. I do not ship a packaged `base-chart-*.tgz` next to the parent.

## Who this page is for

Hiring lead: this is one microservice, not a 30-service farm. Engineer: the parent is overlay. Workload objects come from `_libs/base-chart`.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Umbrella + alias | Parent depends on `base-chart` as `application`. Condition `application.enabled` |
| ExternalSecret | Seven keys: Kafka client password, datasource and Flyway user/password, JWT private/public key. ClusterSecretStore `vault-cluster-secret-store` |
| Kafka truststore init | `extraVolumes` + `initContainers` build a JKS from `kafka-ca-cert` before the JVM starts SASL_SSL |
| Istio sidecar | Inject on, proxy 100m / 128Mi |
| authDelegator | ServiceAccount binds `system:auth-delegator` so Vault Kubernetes auth can work |
| Ingress + CORS | nginx, TLS, rewrite, `x-forwarded-prefix` for a path-mounted OIDC issuer |
| envify | Nested `application.env` becomes a Secret through the library helper |

## How the umbrella is wired

1. Parent templates only the ExternalSecret (and unused helpers).
2. `application:` values are the subchart. Deployment, Service, Ingress, probes, HPA/VPA, ServiceMonitor, and the env Secret live in `_libs/base-chart`.
3. `extraEnvFrom` mounts `estate-auth-vault-secrets` next to that env Secret.
4. JAAS uses `${kafkaClientPassword}` so the ESO key is interpolated at runtime, not stored in values.

## What this chart is not

- Not the Keycloak overlay (that is a different app folder).
- Not the operator UI (`front-base`).
- Not a vendored Bitnami or Kafka operator tree.
- Not Argo Application manifests or repo secrets.

## Sanitize

Hosts are `*.example.com`. Postgres is `10.10.0.10`. Image and wait-for registries are `example.registry`. Vault URI is `https://vault.example.com`. Store passwords in values are `CHANGE_ME`. The JVM `cacerts` default `changeit` appears only as the source password on `keytool -storepasswd`. Brand names, live CIDR, and CI includes stay out.

**Keywords:** Helm umbrella, base-chart, file:// dependency, External Secrets, Vault Kubernetes auth, Istio sidecar, Kafka SASL_SSL, truststore initContainer, OIDC issuer
