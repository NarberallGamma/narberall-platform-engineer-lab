# OpenStack / Selectel

**Role:** Platform Engineer. OpenStack networking and guests for Kubernetes, GitLab, and Postgres.

## What I owned

- Networks, subnets, floating IPs, security groups
- Compute instances: bastion, kube masters/workers, GitLab, Postgres
- Block volumes and attachments, server groups
- Kubernetes platform on those guests (I install and operate)

## Terraform in this lab

| Path | What |
|------|------|
| [`../terraform/openstack-selectel/`](../terraform/openstack-selectel/) | Sanitized root: network, kube/GitLab/Postgres VMs, volumes, SG |

Resource types: [`../terraform/RESOURCES.md`](../terraform/RESOURCES.md)

## Keywords

OpenStack, Selectel, Terraform, Kubernetes, GitLab, PostgreSQL, networking, block storage
