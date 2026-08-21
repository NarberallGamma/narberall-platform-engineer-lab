# Diagrams: CI catalog (turnkey)

Hub: [`../../iac/ci/`](../../iac/ci/).  
Pipelines folder: [`../../iac/ci/pipelines/`](../../iac/ci/pipelines/).  
Case: [`../../case-studies/13-ci-pipelines.md`](../../case-studies/13-ci-pipelines.md).

## Controllers

```mermaid
flowchart TB
  subgraph controllers [CI controllers]
    JK[Jenkins plugins K8s workers]
    GL[GitLab CI]
    GHA[GitHub Actions]
  end
  GL --> Argo[Argo CD]
  JK --> Reg[registry + packages]
  GL --> Reg
  GHA --> Reg
  Argo --> K8s[Kubernetes]
  JK --> ANS[Ansible hosts]
  GL --> ANS
```

Jenkins: earlier and mid estates, workers moved from dedicated VMs onto Kubernetes.  
GitLab CI + Argo CD: more of the recent work. Same stages; different YAML.  
GitHub Actions: three published workflows (werf, Helm KinD, Go).

## Living kits (one include per mechanic)

```mermaid
flowchart LR
  Hub[iac/ci hub] --> Host[host-lifecycle]
  Hub --> Estate[common-ci-estate]
  Hub --> Java[java-gradle]
  Hub --> Werf[werf-retail and delivery]
  Hub --> Other[jenkins GHA helmfile]
  Estate --> Rel[nested releases]
  Java --> Sonar[Sonar AppSec]
  Werf --> Trivy[Trivy Sonar]
```

Published scan boxes here are SonarQube and Trivy.

## Full lifecycle

```mermaid
flowchart TB
  Create[Create_infra_VM_K8s] --> Accompany[Accompany_drift_patch_docs]
  Create --> Build[Build_Java_and_others]
  Build --> Gates[Sonar_Trivy]
  Gates --> MR[MR_and_merge_policy]
  MR --> Publish[Publish_image_chart_lib]
  Publish --> Deploy[Deploy_Argo_or_Ansible]
  Deploy --> Update[Update_promote]
  Update --> Revoke[Revoke_cleanup]
  Accompany --> Revoke
```

## Host one-button (published example)

```mermaid
flowchart LR
  Plan[terraform_plan] --> Apply[terraform_apply]
  Apply --> SSH[wait_ssh]
  SSH --> ANS[ansible_bootstrap]
  ANS --> Vault[Vault]
  ANS --> Mon[monitoring]
  Apply --> Docs[inventory_diagrams]
```

Code for that last diagram: [`../../iac/ci/pipelines/host-lifecycle.gitlab-ci.yml.example`](../../iac/ci/pipelines/host-lifecycle.gitlab-ci.yml.example).
