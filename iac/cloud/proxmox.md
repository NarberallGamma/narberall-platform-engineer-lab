# Proxmox

**Business:** guests as code so a new GitLab/Postgres/k8s node is days, not a rebuild. Selectel dedicated uses the same VE class. Owned-list below stays.

**Role:** Platform Engineer. Proxmox VE guests for Kubernetes, GitLab, and Postgres.

## What I owned

- `proxmox_vm_qemu` guests: kube masters/workers, GitLab, Postgres with data disks
- Provider + remote state (GitLab HTTP backend pattern)
- Same platform sequence as public cloud: guests → Kubernetes I run → CI/CD
- **Selectel dedicated:** Proxmox VE on Selectel-hosted hypervisors (role-split kube pools, Ceph, dual-NIC edge). Same provider, different facility than generic on-prem VE.

## Terraform in this lab

| Path | What |
|------|------|
| [`../terraform/proxmox/`](../terraform/proxmox/) | Sanitized VE root |
| [`../terraform/selectel/proxmox-dc/`](../terraform/selectel/proxmox-dc/) | Selectel DC hypervisors, pool-per-role guests |

Resource types: [`../terraform/RESOURCES.md`](../terraform/RESOURCES.md)

Cluster Helm: [`../helm/`](../helm/).

## Keywords

Proxmox, Proxmox VE, Terraform, Kubernetes, GitLab, PostgreSQL, on-prem
