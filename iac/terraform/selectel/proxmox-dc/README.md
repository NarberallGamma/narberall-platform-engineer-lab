# Selectel dedicated: Proxmox on hosted hypervisors

Sanitized slice of a production-shaped estate: role-split Kubernetes node pools, Ceph OSDs, analytics/test DB, cron workers, search, GitLab, and a dual-NIC VPN.

| File | Guests |
|------|--------|
| `pools.tf` | kube master/worker/frontend/ws/sts/system/logging/isolated/test, db, crons, search, ceph |
| `edge.tf` | GitLab + runner, VPN (LAN `vmbr0` + WAN `vmbr1`) |
| `modules/guest` | Counted `proxmox_vm_qemu` with optional extra disks |

HV names are generic (`pve-sel-01`). LAN is `10.20.22.0/24`. WAN uses documentation addresses (`203.0.113.0/28`).

The telmate provider does not reject a colliding `vmid` or name. Unique names are mandatory before apply.

Hub: [`../README.md`](../README.md). Experience: [`../../../cloud/selectel.md`](../../../cloud/selectel.md).
