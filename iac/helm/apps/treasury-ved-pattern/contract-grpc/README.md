# Contract gRPC overlay (Helm)

**Business first:** HTTP and gRPC share one pod and need **two Services**, not a second chart. Hub: [`../../../README.md`](../../../README.md). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I published a thin umbrella: Chart.yaml, values, one ExternalSecret, overlay helpers, and an extra ClusterIP Service on **:6865**. The workload chart is `file://../_libs/base-chart` (one copy for this pattern). I did not vendor `base-chart` here.

Sibling umbrellas in the same estate used the same gRPC port with hardcoded `app.kubernetes.io/name: application`. This SAMPLE wires Service labels through overlay helpers so chart name, version, and instance stay consistent.

```text
contract-grpc/
  Chart.yaml                      # alias application -> file://../_libs/base-chart 0.2.1
  values.yaml                     # HTTP :8080 + gRPC :6865, Istio, Kafka truststore init
  templates/
    _helpers.tpl                  # contract-grpc.labels / selectorLabels
    grpc-service.yaml             # extra Service <release>-grpc :6865
    external-secret.yaml          # Kafka password + Postgres / Flyway keys
```

I do not ship `Chart.lock` or a packaged `base-chart-*.tgz`. Run `helm dependency update` from this directory so Helm records the shared lib. `.gitignore` ignores a local `charts/` tree.

Render:

```bash
helm dependency update
helm template estate . --namespace estate
```

## Extra gRPC Service

`base-chart` already emits the HTTP Service (`application.service.port: 8080`). The Java process also listens on **6865**. I add a second Service in the overlay instead of forking the library chart.

```yaml
metadata:
  name: {{ .Release.Name }}-grpc
  labels:
    {{- include "contract-grpc.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    - port: 6865
      targetPort: 6865
      name: grpc
  selector:
    app.kubernetes.io/name: {{ include "contract-grpc.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
```

The Service name follows **release**, not `fullnameOverride`. With `helm template estate`, the object is `estate-grpc`. Container port `grpc: 6865` and `application.env.grpc.server.port` must stay aligned.

## Helper labels

`templates/_helpers.tpl` defines `contract-grpc.name`, `fullname`, `chart`, `labels`, and `selectorLabels`. The gRPC Service **includes** `contract-grpc.labels` for metadata. Selectors call `contract-grpc.name` plus `.Release.Name`.

That is the delta versus the hardcoded-label clones: helpers keep `helm.sh/chart` and `app.kubernetes.io/version` on the extra Service. A rename of the overlay chart updates both the HTTP affinity match and the gRPC selector from one define.

Anti-affinity in values matches the same keys:

```yaml
app.kubernetes.io/name: contract-grpc
app.kubernetes.io/instance: estate
```

Pod labels still come from `base-chart`. With alias `application`, the library selector is `app.kubernetes.io/name: application`. The overlay gRPC Service selects `contract-grpc` via helpers. That mismatch is in the original umbrella (helpers on the extra Service, alias on the pod). Sibling clones hardcoded `application` and would match pods. I kept the helper selector because that is the SAMPLE delta. Anti-affinity in values uses the same overlay keys, so it has the same caveat.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Extra Service :6865 | One process, two ports, two ClusterIPs. HTTP stays in `base-chart` |
| Helper labels | Overlay `include`, not hardcoded `application` keys |
| `file://../_libs/base-chart` | Shared umbrella lib. This folder is overlay only |
| Values + ExternalSecret | Kafka SASL_SSL truststore init, Vault Kubernetes auth, sibling HTTP URLs |
| Istio inject | Sidecar on the same pod that exposes gRPC |

## Shared library (not vendored)

| Chart | Pin | What I changed | In git |
|-------|-----|----------------|--------|
| base-chart | 0.2.1 | Extra gRPC Service + helpers in the umbrella | `../_libs/base-chart` (one copy) |

## Sanitize

Hosts are `*.example.com`. Postgres is `10.10.0.10`. Image and init image use `example.registry`. Vault URI is `https://vault.example.com`. Kafka bootstrap is `kafka-{0,1,2}.kafka.example.com:9093`. Store passwords in values are `CHANGE_ME`. The JVM `cacerts` default `changeit` appears only as the source password on `keytool -storepasswd`. Namespace and `fullnameOverride` are `estate`.

**Keywords:** Helm overlay, gRPC Service, helper labels, base-chart, External Secrets, Istio, Kafka truststore, Camunda
