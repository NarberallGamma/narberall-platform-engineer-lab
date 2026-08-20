# NOTES

CI pulls the **upstream** External Secrets Operator chart and applies `values.yaml` from this folder. Templates and CRDs are not vendored here.

The install tree I used later (chart **2.9.0**) lives in the mesh/ESO kit. This wrapper is the HA overlay: 2 replicas on the controller, cert-controller, and webhook, preferred anti-affinity, PDB `minAvailable: 1`, rolling update `maxSurge: 0`.

ClusterSecretStore is created by the Vault thin wrap, not by this chart.
