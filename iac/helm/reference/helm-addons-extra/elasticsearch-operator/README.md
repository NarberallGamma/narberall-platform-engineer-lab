# ECK operator

**Business first:** Elasticsearch in the cluster is an **operator**, then CRs. This slice is the install. The logging stack CRs are in [`../elk/`](../elk/). Hub: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

Upstream `eck-operator` 3.1.0 is not vendored. Chart.yaml + values + Chart.lock pin what I turned: system-node placement, webhook, ServiceMonitor, image rewrite keys.

```text
elasticsearch-operator/
  Chart.yaml                 # wrapper, dep eck-operator 3.1.0
  Chart.lock                 # digest pin
  values.yaml
  .helmignore
  werf.yaml                  # from elastic/eck-operator:3.1.0
```

```bash
helm repo add elastic https://helm.elastic.co
helm dependency build
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Values wrapper | No local templates. CI pulls Elastic Helm |
| Placement | Deckhouse system-node selector, toleration, nodeAffinity |
| Webhook | enabled, `failurePolicy: Ignore`, operator-managed certs |
| ServiceMonitor | on, `insecureSkipVerify: true` |
| Image rewrite | `config.containerRegistry` / `containerRepository` for a private registry |
| PDB | minAvailable 1 on a single replica (install-time caution) |

## Vendor chart (documented, not vendored)

| Chart | Pin | What I changed | In git |
|-------|-----|----------------|--------|
| eck-operator | 3.1.0 from helm.elastic.co | placement, webhook, ServiceMonitor, registry rewrite | Chart.yaml + values + lock |

A separate eck-stack values file (cluster + Kibana + Logstash CRs) stays out. It duplicated this operator plus a thinner cluster than `elk/`.

## Sanitize

Registry is `example.registry` / `platform/elasticsearch`. Image pull secret name stays `registrysecret`. No PEM, no secret-values.

**Keywords:** ECK, elasticsearch-operator, Helm, Deckhouse, ServiceMonitor, werf
