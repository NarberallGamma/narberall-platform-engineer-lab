# Brownfield import checklist (fake IDs)

Use after writing Terraform that matches live resources. Never commit real UUIDs or state.

Network and NGFW are **already** in a sibling Terragrunt live. Do not import those addresses into this root.

```bash
# 1) Inventory / audit (read-only)  -  private tooling; not in this repo
# 2) Write resource blocks that match reality (catalog keys, not raw UUIDs in ECS/CCE/RDS files)
# 3) Import (examples with fake IDs)

# CCE
terraform import 'sbercloud_cce_cluster.dev_01'     00000000-0000-4000-8000-000000000301
terraform import 'sbercloud_cce_cluster.preprod_01' 00000000-0000-4000-8000-000000000302
terraform import 'sbercloud_cce_cluster.prod_01'    00000000-0000-4000-8000-000000000303

# RDS (provider IDs end with in03 on this cloud)
terraform import 'sbercloud_rds_instance.prod_01'    00000000000000000000000000000001in03
terraform import 'sbercloud_rds_instance.preprod_01' 00000000000000000000000000000002in03
terraform import 'sbercloud_rds_instance.dev_01'     00000000000000000000000000000003in03

# GitLab
terraform import 'sbercloud_compute_instance.gitlab_dev'  00000000-0000-4000-8000-000000000401
terraform import 'sbercloud_evs_volume.gitlab_dev__vol0'  00000000-0000-4000-8000-000000000501
terraform import 'sbercloud_compute_instance.gitlab_prod' 00000000-0000-4000-8000-000000000402
terraform import 'sbercloud_evs_volume.gitlab_prod__vol0' 00000000-0000-4000-8000-000000000502

# Vault
terraform import 'sbercloud_compute_instance.vault_dev'  00000000-0000-4000-8000-000000000403
terraform import 'sbercloud_evs_volume.vault_dev__vol0'  00000000-0000-4000-8000-000000000503
terraform import 'sbercloud_compute_instance.vault_prod' 00000000-0000-4000-8000-000000000404
terraform import 'sbercloud_evs_volume.vault_prod__vol0' 00000000-0000-4000-8000-000000000504

# AppSec
terraform import 'sbercloud_compute_instance.appsec_nessus'     00000000-0000-4000-8000-000000000405
terraform import 'sbercloud_evs_volume.appsec_nessus__vol0'     00000000-0000-4000-8000-000000000505
terraform import 'sbercloud_compute_instance.appsec_semgrep'    00000000-0000-4000-8000-000000000406
terraform import 'sbercloud_evs_volume.appsec_semgrep__vol0'    00000000-0000-4000-8000-000000000506
terraform import 'sbercloud_compute_instance.appsec_dtrack'     00000000-0000-4000-8000-000000000407
terraform import 'sbercloud_evs_volume.appsec_dtrack__vol0'     00000000-0000-4000-8000-000000000507
terraform import 'sbercloud_compute_instance.appsec_defectdojo' 00000000-0000-4000-8000-000000000408
terraform import 'sbercloud_evs_volume.appsec_defectdojo__vol0' 00000000-0000-4000-8000-000000000508

# Test leftovers
terraform import 'sbercloud_compute_instance.ecs_test_prod'    00000000-0000-4000-8000-000000000409
terraform import 'sbercloud_evs_volume.ecs_test_prod__vol0'    00000000-0000-4000-8000-000000000509
terraform import 'sbercloud_compute_instance.ecs_test_preprod' 00000000-0000-4000-8000-000000000410
terraform import 'sbercloud_evs_volume.ecs_test_preprod__vol0' 00000000-0000-4000-8000-000000000510

# 4) Reconcile HCL to state (NIC IP, volume name, security_group_ids, HA AZ)
terraform plan -refresh-only
terraform plan
# Goal: No changes (or only intentional drift fixes in code)

# 5) Do not import
#    NGFW ECS, NGFW EIP/VIP, preprod EIP, custom NGFW route table
#    CCE node-pool ECS
#    anything already under live/<env>/<unit>/
```

Private run imported the compute addresses above with fail=0, then aligned HCL until plan exit 0. Apply was not used to "fix" the estate. Teleport was a later `apply` of a new address, not an import.
