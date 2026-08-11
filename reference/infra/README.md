# Infrastructure as Code (Terraform)

How I work with Terraform: greenfield adoption, reusable modules, Terragrunt, multi-env roots, and brownfield import until `plan` is clean.

Also shows **era differences**: current cloud.ru-class code vs legacy AWS / Selectel (Flant-era clients).

## Start here

| Want to see | Go to |
|-------------|-------|
| Current modules + K8s/RDS/OBS root | [`modules/`](modules/), [`patterns/multi-env-root/`](patterns/multi-env-root/) |
| Terragrunt DRY live | [`patterns/terragrunt-live/`](patterns/terragrunt-live/) |
| Legacy AWS style | [`eras/legacy-aws/`](eras/legacy-aws/) |
| Legacy Selectel/OpenStack | [`eras/legacy-openstack-selectel/`](eras/legacy-openstack-selectel/) |
| Era index | [`eras/README.md`](eras/README.md) |

## Map

| Path | What |
|------|------|
| [`eras/`](eras/) | Current vs legacy code samples |
| [`modules/`](modules/) | Reusable building blocks |
| [`patterns/multi-env-root/`](patterns/multi-env-root/) | One root, several environments (network, ECS, CCE, RDS, OBS) |
| [`patterns/terragrunt-live/`](patterns/terragrunt-live/) | Terragrunt sample env |
| [`patterns/multi-cloud-notes/`](patterns/multi-cloud-notes/) | Short multi-cloud notes |
| [`examples/`](examples/) | Greenfield compose + brownfield import checklist |
| [`SANITIZE.md`](SANITIZE.md) | Publish rules |

## Keywords

Terraform, Terragrunt, IaC, modules, multi-env, brownfield import, remote state, AWS, OpenStack, Selectel, Kubernetes, RDS, OBS, cloud platform

## Case studies

- [Cloud platform turnkey (greenfield)](../../case-studies/02-cloud-platform-turnkey.md)
- [Brownfield import into Terraform state](../../case-studies/04-terraform-brownfield-import.md)
