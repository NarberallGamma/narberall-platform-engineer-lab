# Vault thin wrap

I used this chart when Vault already ran **outside** the cluster. Helm only created the ESO ServiceAccount, the `system:auth-delegator` binding, and one `ClusterSecretStore`.

`server`, `injector`, `csi`, and `ui` stay `false`. Address in values is `https://vault.example.com`.

I did not copy the full in-cluster Vault tree (server StatefulSet, injector, CSI). That DEMO chart is not in this kit. Pin in the estate README: HashiCorp chart metadata **0.28.1**.

```text
vault/
  Chart.yaml
  values.yaml
  templates/
    vault-cluster-secret-store.yaml
    external-secrets-serviceaccount.yaml
    external-secrets-clusterrolebinding.yaml
    _helpers.tpl
    NOTES.txt
```

Helpers are the thin-wrap set (name, namespace, labels). Unused upstream server/injector/CSI helpers are not here.

Install into the namespace that owns the ESO Vault ServiceAccount:

```bash
helm upgrade --install vault . -n external-secrets
```

**Keywords:** Vault, ClusterSecretStore, External Secrets, Kubernetes auth
