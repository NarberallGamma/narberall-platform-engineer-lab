# ELK overlay (ECK)

**Business first:** logging is **CRs I wrote**, not an `eck-stack` values dump. Hub: [`../`](../). Operator install: [`../elasticsearch-operator/`](../elasticsearch-operator/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I ran Elasticsearch 8.12.0 (5 nodes, **3100Gi** PVC per node, about 3 Ti, dedicated logging nodes), Kibana 8.12.0 (Dex in front of ingress), Deckhouse ClusterLoggingConfig / ClusterLogDestination, a Logstash pipeline for SDK JSON, ILM plus index templates uploaded by a post-upgrade Job, and an elasticsearch_exporter. `dashboards/elasticsearch.json` is a Grafana artefact next to the chart (same habit as the estate overlay: sidecar off unless a later mount is added). The eck-logstash 0.11.0 tarball stays out.

```text
elk/
  Chart.yaml                 # elk 0.1.0, dep eck-logstash 0.11.0 (not vendored)
  requirements.lock          # pin digest
  values.yaml
  werf.yaml                  # exporter v1.3.0, ubuntu 24.04, logstash 8.14.0
  dashboards/elasticsearch.json
  templates/
    elasticsearch.yaml       # ECK Elasticsearch CR
    kibana.yaml
    kibana-ingress.yaml      # nginx + Dex auth-url + basic to ES
    kibana-dex-auth.yaml
    logshipper-cr.yaml       # Deckhouse destinations + pod configs
    logstash-role.yaml
    templates.yaml           # index templates + ILM + upload script
    template-upload.yaml     # helm hook Job
    exporter.yaml
    grafana-dashboards.yaml
    _env_lib.tpl             # env-pluck helpers (fl.value)
    _helper.tpl
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| ECK CRs | 5-node ES with `maxUnavailable: 1`, privileged sysctl init, `3100Gi` PVC |
| Dex + ingress | auth-url to `kibana-kb-http-dex-authenticator`, TLS secret from values |
| Logshipper | Several ClusterLogDestination indexes and label/namespace routes |
| ILM Job | post-upgrade hook uploads templates (fields limit 2000, flattened request bodies) |
| Logstash | TCP 12345 + Beats 5044, JSON filter, env-based target index |
| Exporter | elasticsearch_exporter on the logging node pool |

## Vendor chart (documented, not vendored)

| Chart | Pin | What I changed | In git |
|-------|-----|----------------|--------|
| eck-logstash | 0.11.0 from helm.elastic.co | pipelines, role, TCP/Beats services, STS node pool | values + lock only |
| ECK operator | see elasticsearch-operator | CRDs come from the operator slice | not here |

A thinner eck-stack cluster values file (ES + Kibana + Logstash CRs only) stays out. This overlay is the logging story.

## Sanitize

Kibana host is `kibana.example.com`. Dex groups are `platform` / `platform-staff` / `platform-admin`. Logshipper CA and ES password are `CHANGE_ME` (no PEM, no secret-values). Image pull secret name stays `registrysecret`.

**Keywords:** Elasticsearch, Kibana, Logstash, ECK, Deckhouse, Dex, ILM, elasticsearch_exporter, werf
