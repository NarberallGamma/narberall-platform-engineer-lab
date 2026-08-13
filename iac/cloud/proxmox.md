# Proxmox

**Role:** Platform Engineer. Proxmox VE guests for Kubernetes, GitLab, and Postgres.

## What I owned

- `proxmox_vm_qemu` guests: kube masters/workers, GitLab, Postgres with data disks
- Provider + remote state (GitLab HTTP backend pattern)
- Same platform sequence as public cloud: guests → Kubernetes I run → CI/CD

## Terraform in this lab

| Path | What |
|------|------|
| [`../terraform/proxmox/`](../terraform/proxmox/) | Sanitized VE root |

Resource types: [`../terraform/RESOURCES.md`](../terraform/RESOURCES.md)

## Keywords

Proxmox, Proxmox VE, Terraform, Kubernetes, GitLab, PostgreSQL, on-prem
