# Google Cloud

**Role:** Platform Engineer. Project and network bootstrap through compute and delivery into GKE-class / VM workloads.

## What I owned

- Project / IAM-adjacent baseline and network layout
- Compute for app and platform hosts
- Delivery into GKE-class clusters or VM workloads
- Same greenfield sequence as other clouds: access → network → compute/data → Kubernetes → CI/CD

Published Terraform in this lab is concentrated on Huawei-class, AWS, Selectel, and VK Cloud samples (same ownership pattern). No leftover client GCP `.tf` tree to publish. See [`../terraform/COVERAGE.md`](../terraform/COVERAGE.md).

## Related code

- Pattern reference: [`../terraform/aws/`](../terraform/aws/), [`../terraform/cloud-ru-huawei/`](../terraform/cloud-ru-huawei/)
- Delivery story: [turnkey from zero](../../case-studies/02-cloud-platform-turnkey.md)

## Keywords

Google Cloud, GCP, GKE, IAM, VPC, Terraform, Kubernetes, CI/CD
