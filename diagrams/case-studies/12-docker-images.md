# Diagram: Docker images and Compose stacks

```mermaid
flowchart TB
  subgraph ciHub [iac/ci]
    Pipe[pipelines YAML]
  end
  subgraph images [iac/docker/images]
    CIImg[ci pins and runners]
    Ops[operators]
    Apps[one mechanic per app]
  end
  subgraph compose [iac/docker/compose]
    Sec[sec-stack 8 services]
    Host[GitLab Omnibus plus Vault]
    Local[dev-deps plus java-local-dev]
    Collab[collab Atlassian Nextcloud n8n OCR Kafka]
  end
  subgraph after [after the push]
    Reg[registry]
    Helm[iac/helm Argo]
  end
  Pipe --> images
  CIImg -->|docker build| Reg
  Ops -->|docker build| Reg
  Apps -->|docker build| Reg
  Reg --> Helm
  Reg --> compose
  Sec --> AnsibleCopy[extras/sec-stack/stack]
```

Case study: [`../../case-studies/12-docker-images.md`](../../case-studies/12-docker-images.md).  
Docker hub: [`../../iac/docker/`](../../iac/docker/).  
Images: [`../../iac/docker/images/`](../../iac/docker/images/).  
Compose: [`../../iac/docker/compose/`](../../iac/docker/compose/).  
CI catalog: [`../../iac/ci/`](../../iac/ci/).  
Helm: [`../../iac/helm/`](../../iac/helm/).  
SRE layers: [`../../docs/sre/layers.md`](../../docs/sre/layers.md).  
sec-stack Ansible copy: [`../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/stack/`](../../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/stack/).

No real IPs, employer names, or live hostnames in labels.
