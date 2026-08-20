# Diagram: Huawei-class estate Ansible

```mermaid
flowchart TB
  subgraph inv [Inventory]
    Prod[prod]
    Pre[preprod]
    Demo[demo]
  end
  subgraph base [Host baseline]
    Prep[prepare_servers]
    Vps[prepare_vps_cluster]
    Users[bootstrap users]
  end
  subgraph apps [docker_app]
    LB[edge LB]
    HSM[HSM adapter]
    CP[CryptoPro]
    GL[GitLab nginx]
    Cert[cert orchestrator]
    GW[treasury gateway]
    Hib[hibernate operator]
  end
  subgraph data [Data and secrets]
    Vlt[Vault]
    DB[estate_databases]
    Exp[node-exporter]
  end
  subgraph scrape [Host scrape siblings]
    Prom[app-platform Prom]
    VM[VictoriaMetrics]
    HostG[sec-stack Grafana]
  end
  inv --> base
  base --> apps
  apps --> data
  Exp --> Prom
  Prom --> VM
  VM --> HostG
```

Case study: [`../../case-studies/10-ansible-estate.md`](../../case-studies/10-ansible-estate.md).  
In-cluster half: [`../../case-studies/11-helm-estate.md`](../../case-studies/11-helm-estate.md).  
SRE catalog: [`../../docs/sre/`](../../docs/sre/). Product APIs: [`../../architecture/06-product-apis.md`](../../architecture/06-product-apis.md).  
Host kits: [`../../iac/ansible/reference/ansible-estate/`](../../iac/ansible/reference/ansible-estate/), [`../../iac/ansible/reference/ansible-app-platform/`](../../iac/ansible/reference/ansible-app-platform/), [`../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/`](../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/).

No real IPs, employer names, or live hostnames in labels.
