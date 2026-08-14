# Diagrams: CI catalog (turnkey)

Hub: [`../../iac/ci/`](../../iac/ci/).  
Pipelines folder: [`../../iac/ci/pipelines/`](../../iac/ci/pipelines/).

## Controllers

```mermaid
flowchart TB
  subgraph controllers [CI controllers]
    JK[Jenkins plugins K8s workers]
    GL[GitLab CI]
  end
  GL --> Argo[Argo CD]
  JK --> Reg[registry + packages]
  GL --> Reg
  Argo --> K8s[Kubernetes]
  JK --> ANS[Ansible hosts]
  GL --> ANS
```

Jenkins: earlier and mid estates, workers moved from dedicated VMs onto Kubernetes.  
GitLab CI + Argo CD: more of the recent work. Same stages; different YAML.

## Full lifecycle

```mermaid
flowchart TB
  Create[Create_infra_VM_K8s] --> Accompany[Accompany_drift_patch_docs]
  Create --> Build[Build_Java_and_others]
  Build --> Gates[Sonar_Trivy_OSV]
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
