# Cluster addons pipeline (Istio + ESO)

**Business first:** mesh and External Secrets are **manual Helm upgrades from CI**, then the estate kit adds policies. Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

I used this pipeline when the platform repo vendored Istio `base` + `istiod` and the ESO chart, and a GitLab runner ServiceAccount applied them. Jobs are all `when: manual` on `main`. Deploy image is `ci/helmfile` with kubectl (pin 0.169.1 / Helm 3.18.6 / kubectl 1.34.3).

```text
cluster-addons/
  .gitlab-ci.yml.example    # Istio deploy/rollback, ESO deploy/store/examples/verify/rollback
```

Install charts: [`../../../helm/reference/helm-mesh-eso/`](../../../helm/reference/helm-mesh-eso/) (Istio 1.30.3, ESO 2.9.0).  
Estate policies and Vault ClusterSecretStore wrap: [`../../../helm/reference/helm-estate-cluster/`](../../../helm/reference/helm-estate-cluster/).  
Image CI stays next to the Dockerfile: [`../../../docker/images/ci/helmfile/`](../../../docker/images/ci/helmfile/).

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Stage split | Istio first, then ESO operator, store, examples, verify, rollback. Each stage is its own click |
| `.k8s_helm` + CRD probe | Job fails closed if the runner ServiceAccount cannot `create customresourcedefinitions` |
| Vendored chart `test -f` | Apply does not pull chart packages. `Chart.yaml` must sit next to the pipeline |
| Istio 1.30.3 / ESO 2.9.0 | Same pins as the mesh install kit |
| Rollback jobs | `helm rollback` plus example delete. ClusterSecretStore stays unless deleted by hand |

## Honest gaps

- RBAC (`rbac/gitlab-runner-cluster-resources.yaml`) is not in this folder. The before_script tells an admin to apply it once from a kubeconfig.
- Vendored trees are not copied here. The live CI repo used `istio/charts/{base,istiod}` and `eso/charts/external-secrets`. The lab install kit uses `istio/` and `external-secrets/` (not `eso/`). Path rewrite is a consumer step, not invented YAML.
- `eso/manifests/*` and `eso/examples/` (namespace, Vault SA, ClusterSecretStore, demo ExternalSecret) are not in this folder. Store/examples jobs 404 until those files sit next to the pipeline or the estate Vault wrap is pointed at.
- The runner talks to the cluster API as a privileged ServiceAccount. That is the real shape.

**Keywords:** GitLab CI, Istio, istiod, External Secrets Operator, helmfile image, manual deploy
