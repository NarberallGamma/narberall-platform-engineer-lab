# Diagrams: Docker / Compose hub

Hub: [`../../iac/docker/`](../../iac/docker/).  
Images: [`../../iac/docker/images/`](../../iac/docker/images/).  
Compose: [`../../iac/docker/compose/`](../../iac/docker/compose/).  
Pipelines stay in [`../../iac/ci/`](../../iac/ci/).

## CI builds image, then Helm or Compose

```mermaid
flowchart LR
  Pipe[iac/ci pipelines] --> Ctx[iac/docker/images]
  Ctx -->|docker build| Reg[registry]
  Reg --> Helm[iac/helm Argo]
  Reg --> Comp[iac/docker/compose up]
```

## What lives where

```mermaid
flowchart TB
  subgraph dockerHub [iac/docker]
    Hub[this tree]
    Img[images]
    Comp[compose]
  end
  subgraph img [images]
    CI[ci]
    Ops[operators]
    Apps[apps]
  end
  subgraph stacks [compose]
    Sec[sec-stack]
    Omnibus[gitlab-omnibus]
    Vault[vault]
    Deps[dev-deps]
    Java[java-local-dev]
    Collab[collab]
  end
  Hub --> Img
  Hub --> Comp
  Img --> img
  Comp --> stacks
  Sec --> Extra[extras/sec-stack/stack]
```

Case: [`../../case-studies/12-docker-images.md`](../../case-studies/12-docker-images.md).  
Sanitize: [`../../iac/docker/SANITIZE.md`](../../iac/docker/SANITIZE.md).

No real IPs, employer names, or live hostnames in labels.
