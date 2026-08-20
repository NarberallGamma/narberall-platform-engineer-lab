# Data plane (Helm)

**Business first:** a shop-class estate can run **Linkerd + traces + NiFi** without sharing the Istio kit. Hub: [`../../`](../../). Case 01 style shop load: [`../../../../case-studies/01-ai-llm-platform.md`](../../../../case-studies/01-ai-llm-platform.md).

I used this on a delivery / e-commerce Kubernetes estate. Istio lives in [`../helm-estate-cluster/`](../helm-estate-cluster/) and [`../helm-mesh-eso/`](../helm-mesh-eso/). This kit is the **other** mesh plus the only Jaeger and NiFi charts in the lab.

```text
helm-data-plane/
  linkerd/          # control plane + CRDs + viz (issuer keys stripped)
  jaeger/
  nifi/
  autostand-dev/    # SAMPLE contrast: in-cluster Kafka / Postgres / MinIO
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Linkerd | Second mesh in the portfolio. Trust anchors are examples only |
| Jaeger | Traces for a 50-service shop, not a sidecar screenshot |
| NiFi | Document / integration flows next to the shop |
| DEV autostand | In-cluster Kafka/Postgres/MinIO as a **contrast** to Strimzi + RDS in the estate kit. Not a second Kafka production story |

Pull-secret and binary truststore files stay out. Pattern is NOTES in the slice README.

**Keywords:** Linkerd, Jaeger, NiFi, MinIO, Kafka, PostgreSQL, autostand
