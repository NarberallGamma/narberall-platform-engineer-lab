# Diagrams: Helm / GitOps hub

Hub: [`../../iac/helm/`](../../iac/helm/).  
Cluster kits: [`../../iac/helm/reference/`](../../iac/helm/reference/).  
Product samples: [`../../iac/helm/apps/`](../../iac/helm/apps/).  
Case: [`../../case-studies/11-helm-estate.md`](../../case-studies/11-helm-estate.md).

```mermaid
flowchart TB
  subgraph helmHub [iac/helm]
    Ref[reference cluster kits]
    Apps[apps product samples]
  end
  subgraph envelope [helm-estate-cluster]
    Istio[Istio policies]
    ESO[Vault wrap plus ESO]
    Argo[Argo door]
    Obs[Grafana overlay]
  end
  Ref --> envelope
  Apps --> KC[Keycloak overlay]
  Apps --> Ved[estate mechanics]
  Apps --> Pack[helmfile werf OCI]
  envelope --> Case11[case 11]
```

No real IPs or employer names in labels.
