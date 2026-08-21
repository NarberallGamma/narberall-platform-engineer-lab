# Diagram: CI pipelines

```mermaid
flowchart TB
  subgraph controllers [controllers]
    GL[GitLab CI]
    JK[Jenkins]
    GHA[GitHub Actions]
  end
  subgraph kits [iac/ci/pipelines]
    Host[host-lifecycle]
    Estate[common-ci-estate plus releases]
    Java[java-gradle hubs]
    WerfR[werf-retail Trivy Sonar]
    WerfD[werf-delivery review canary]
    Other[werf-other extra mechanics]
    JG[jenkins plus GHA]
    Extra[helmfile-dev cluster-addons kb-example-ci security-gates]
  end
  subgraph after [after the job]
    Reg[registry]
    Argo[Argo CD]
    ANS[Ansible hosts]
  end
  GL --> kits
  JK --> JG
  GHA --> JG
  Host --> ANS
  Estate --> Argo
  Java --> Reg
  WerfR --> Reg
  WerfD --> Argo
  Other --> Reg
  Extra --> Argo
  Reg --> Argo
```

Case study: [`../../case-studies/13-ci-pipelines.md`](../../case-studies/13-ci-pipelines.md).  
CI hub: [`../../iac/ci/`](../../iac/ci/).  
Kits: [`../../iac/ci/pipelines/`](../../iac/ci/pipelines/).  
Host button: [`../../iac/ci/pipelines/host-lifecycle.gitlab-ci.yml.example`](../../iac/ci/pipelines/host-lifecycle.gitlab-ci.yml.example).  
Images: [`../../iac/docker/`](../../iac/docker/).  
Helm: [`../../iac/helm/`](../../iac/helm/).  
Turnkey diagram: [`../iac/ci-turnkey.md`](../iac/ci-turnkey.md).

No real IPs, employer names, or live hostnames in labels.
