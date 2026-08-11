# Platform: Proxmox

| File | Resources |
|------|-----------|
| `kube_masters.tf` / `kube_workers.tf` | K8s + GitLab VMs (`proxmox_vm_qemu`) |
| `postgres.tf` | Postgres guests with data disks |
| `providers.tf` / `backend.tf` / `versions.tf` | Provider + GitLab HTTP state |

Map: [`../../RESOURCES.md`](../../RESOURCES.md)
