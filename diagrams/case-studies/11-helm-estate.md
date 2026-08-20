# Diagram: Huawei-class estate Helm

```mermaid
flowchart TB
  subgraph deliver [Upgrade paths]
    CI[CI helm upgrade]
    Argo[Argo CD door]
  end
  subgraph envelope [Infra charts]
    Istio[Istio policies]
    EG[egress gateway]
    KC[Kafka Connect]
    ESO[Vault wrap plus ESO]
    Obs[Grafana overlay 12 alerts 14 dashboards]
    LB[3 ELB plus ingress]
  end
  subgraph addons [Helm addons other estates]
    EA[ElastAlert2 plus Falco]
    PR[12 PromRules]
    ELK[ELK ECK and OTel]
  end
  subgraph later [Apps]
    Apps[product umbrellas later]
  end
  subgraph ext [Outside CCE]
    VPS[VPS proxy]
    Broker[managed Kafka]
    VaultExt[external Vault]
    RDS[managed RDS]
  end
  subgraph host [Ansible hosts]
    Node[node-exporter]
    AppP[app-platform Prom to VM]
    VM[VictoriaMetrics]
    HostG[host Grafana]
  end
  CI --> envelope
  CI --> Argo
  Argo --> Apps
  Istio --> EG
  EG --> VPS
  KC --> Broker
  KC --> RDS
  ESO --> VaultExt
  Obs -.-> EA
  Obs -.-> PR
  Obs -.-> ELK
  Obs -.-> host
  Node --> VM
  AppP --> VM
  VM --> HostG
```

Case study: [`../../case-studies/11-helm-estate.md`](../../case-studies/11-helm-estate.md).  
Helm hub: [`../../iac/helm/`](../../iac/helm/).  
SRE catalog: [`../../docs/sre/`](../../docs/sre/). Product APIs: [`../../architecture/06-product-apis.md`](../../architecture/06-product-apis.md).  
Overlay volume: [`../../iac/helm/reference/helm-estate-cluster/monitoring/`](../../iac/helm/reference/helm-estate-cluster/monitoring/).  
Host VictoriaMetrics / Grafana: [`../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/`](../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/).  
Host scrape (Prom to VM): [`../../iac/ansible/reference/ansible-app-platform/`](../../iac/ansible/reference/ansible-app-platform/).  
Host node scrape: [`../../iac/ansible/reference/ansible-estate/`](../../iac/ansible/reference/ansible-estate/).

No real IPs, employer names, or live hostnames in labels.
