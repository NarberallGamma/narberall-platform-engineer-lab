# Deckhouse authorization (werf teaching tree)

**Business first:** cluster RBAC is a CR, not a wiki table of ClusterRoles. Hub: [`../`](../).

I used this tree to ship Deckhouse `ClusterAuthorizationRule` objects from a werf project. There is no `Chart.yaml`. The chart lives under `.helm/` the way many Deckhouse-era jobs did.

```text
d8-authz/
  werf.yaml
  .gitlab-ci.yml
  .helm/
    values.yaml
    templates/10-rbac-rules.yaml
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `.helm` without `Chart.yaml` | Teaching shape I actually applied (werf-raw), not a Helm starter |
| `ClusterAuthorizationRule` | Deckhouse CR: subjects, `accessLevel`, scale, port-forward, system namespaces |
| `values.yaml` | Two roles: platform admin vs namespace-limited user |

```bash
# werf-raw: no Chart.yaml. Apply on a Deckhouse cluster:
werf converge --kube-context estate-dev
```

`werf.yaml` stays, sanitized (`project: d8-authz`). CI context is `estate-dev`.

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

**Keywords:** Deckhouse, ClusterAuthorizationRule, werf, RBAC
