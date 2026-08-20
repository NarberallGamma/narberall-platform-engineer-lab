# base-chart (shared library)

I keep one copy of this chart. Estate product umbrellas depend on it with `file://../_libs/base-chart` (alias `application`). Do not vendor a second tree next to those parents.

Version pin (as used): **0.2.1**. Type: application (used as a subchart).

```text
_libs/base-chart/
  Chart.yaml
  values.yaml
  templates/          # Deployment, Service, Ingress, HPA, VPA, Job, ServiceMonitor
  templates/_helpers.tpl   # names plus envify (nested map to Secret data)
```

## What the library renders

| Template | Role |
|----------|------|
| `deployment.yaml` | Workload. Optional wait-for Job init, YAML `initContainers`, or `initContainersTemplate` (`include` of a parent define) |
| `secret-env.yaml` | `envify`: flatten `global.env` and `env` into one Opaque Secret |
| `service.yaml` / `ingress.yaml` | ClusterIP plus optional Ingress |
| `migration.yaml` | One-shot Job; Deployment waits with `k8s-wait-for` when `migrations.enabled` |
| `serviceaccount.yaml` | SA + Role to get Jobs. Optional `system:auth-delegator` ClusterRoleBinding |
| `hpa.yaml` / `vpa.yaml` | Autoscaling off by default |
| `service-monitor.yaml` | Prometheus Operator ServiceMonitor |
| `cm-config.yaml` / `secret-config.yaml` | Optional file config and keystore |

## Notes

- Wait-for image is `example.registry/docker.io/groundnuty/k8s-wait-for:v1.5.1`. Default app image is `example.registry/library/base`.
- `initContainersTemplate` is the named-define path (policy-gateway). `initContainers` is the YAML list (web-ws). The template branch wins when both are set.
- `authDelegator` ClusterRoleBinding subjects the SA in namespace `default`. That is the chart as shipped. A parent that deploys elsewhere needs a local override or a later patch.
- CI includes from the source tree stay out. Run `helm dependency update` on the parent.

**Keywords:** Helm library, subchart, envify, auth-delegator, wait-for Job, ServiceMonitor
