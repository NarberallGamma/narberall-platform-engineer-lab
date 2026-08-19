# Platform: Proxmox

| File | Resources |
|------|-----------|
| `kube_masters.tf` / `kube_workers.tf` | K8s control and workers |
| `postgres.tf` | Postgres guests with data disks |
| `gitlab.tf` / `runner.tf` / `vault.tf` / `monitoring.tf` | GitLab, CI runners, Vault, metrics |
| `providers.tf` / `backend.tf` / `versions.tf` | Provider + GitLab HTTP state |

Experience: [`../../cloud/proxmox.md`](../../cloud/proxmox.md)  
Map: [`../RESOURCES.md`](../RESOURCES.md)
