# Argo CD bootstrap

I used Argo CD as the **application door** only. CI Helm installed the operators. Argo synced the app repos.

This folder is bootstrap: HA values, the `argocd` namespace, and one AppProject. I did not copy Application lists, repo Secrets, or the cluster Secret.

```text
argocd/
  argocd-values.yaml
  manifests/argocd/argocd-namespace.yaml
  manifests/argocd/argocd-project.yaml
  README.md
```

HA I kept: server 2, repoServer 2, applicationSet 2, controller 1 (StatefulSet), preferred anti-affinity, PDB `minAvailable: 1`, rolling `maxSurge: 0`.

Ingress host is `argocd.example.com`. TLS secret name is `wildcard-tls` (see estate `NOTES.md` for DNS-01 / certbot).

**Lab fact:** `configs.params.server.insecure` is `true`. TLS stops on ingress-nginx. Setting it false produced a redirect loop.

Skipped on purpose: `manifests/applications/`, `applications_off/`, `repositories/`, and `clusters/k8s-cluster-secret.yaml` (repo tokens and kube credentials).

**Keywords:** Argo CD, GitOps, HA, ingress, AppProject
