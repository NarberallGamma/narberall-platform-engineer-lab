# kube-ops

Scripts: [`../scripts/k8s/`](../scripts/k8s/), [`../scripts/utility/k8s/argocd_deploy_verify.sh`](../scripts/utility/k8s/argocd_deploy_verify.sh).

Layout on the box:

```text
~/.kube/clusters/<name>/config
~/.kube/config -> clusters/<name>/config
```

| Script | Job |
|--------|-----|
| `kube-switch.sh` | `list` / `current` / name / interactive pick |
| `kube-logs.sh` | Interactive dump of pod logs to a `.log` file |
| `argocd_deploy_verify.sh` | Annotate refresh, wait Synced/Healthy, optional rollout restart |

MCP tools: `kube_list_clusters`, `kube_switch`, `kube_logs`, `argocd_sync_verify` in [`../mcp-agent/tools-catalog.md`](../mcp-agent/tools-catalog.md).
