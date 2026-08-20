# External Secrets Operator (values wrapper)

I ran ESO as the only path from Vault into Kubernetes Secrets. This folder is the **values overlay** I pinned for HA, not a vendored operator tree.

CI pulls the upstream chart (app **0.9.11** on this estate). See `NOTES.md`. The later **install** kit in [`../../helm-mesh-eso/`](../../helm-mesh-eso/) pins ESO **2.9.0**. Both are real: this folder is the HA overlay I used on CCE; the mesh kit is the chart CI upgrades on a newer cluster.

```text
external-secrets-operator/
  Chart.yaml
  values.yaml
  NOTES.md
  README.md
```

What hiring should see: 2 replicas on controller / cert-controller / webhook, preferred anti-affinity on hostname, PDB, ServiceMonitor on.

The Vault wrap in `../vault/` creates `vault-cluster-secret-store`. I did not copy application ExternalSecret lists.

**Keywords:** External Secrets Operator, HA, ServiceMonitor, Vault
