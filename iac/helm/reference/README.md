# Helm reference kits

Sanitized living trees. Hunter map: [`../`](../).

| Kit | What hiring should parse |
|-----|--------------------------|
| [`helm-estate-cluster/`](helm-estate-cluster/) | Istio policies + egress, Kafka Connect/CDC on an external broker, Vault/ESO, Argo bootstrap, 3-ELB, ingress values, Zalando PG, in-cluster observability overlay (Grafana views + CloudEye exporters + OO collector). SRE: [`../../../architecture/05-sre.md`](../../../architecture/05-sre.md), [`../../../docs/sre/`](../../../docs/sre/) |
| [`helm-mesh-eso/`](helm-mesh-eso/) | Full Istio 1.30.3 `base`+`istiod` and ESO 2.9.0 install trees (the estate kit has policies, not these charts) |
| [`helm-data-plane/`](helm-data-plane/) | Linkerd (keys stripped) plus Jaeger and NiFi. DEV in-cluster Kafka/Postgres/MinIO is a contrast sample only |
| [`helm-addons-extra/`](helm-addons-extra/) | MinIO operator, OTel, ELK/ECK, PromRules, ElastAlert2/Falco, SonarQube, Supabase, OpenVPN admin, werf backup, Dagster overlay |
| [`helm-kb-examples/`](helm-kb-examples/) | Four teaching trees: Deckhouse authz, Redis operator, Borg, restic |

Product samples: [`../apps/`](../apps/) (one richest copy per mechanic).
