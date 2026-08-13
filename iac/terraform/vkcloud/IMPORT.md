# Brownfield import checklist (fake IDs)

Use after writing Terraform that matches live resources. Never commit real UUIDs or state.

```bash
# 1) Inventory / audit (read-only)  -  private tooling; not in this repo
# 2) Write resource blocks that match reality (catalog keys, not raw UUIDs in VM files)
# 3) Import (examples with fake IDs)

terraform import 'vkcs_compute_instance.collab_app' 00000000-0000-4000-8000-000000000201
terraform import 'vkcs_blockstorage_volume.collab_app_os' 00000000-0000-4000-8000-000000000202
terraform import 'vkcs_blockstorage_volume.collab_app_data' 00000000-0000-4000-8000-000000000203
terraform import 'vkcs_compute_volume_attach.collab_app_data' 00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000203

terraform import 'vkcs_compute_instance.wiki' 00000000-0000-4000-8000-000000000211
terraform import 'vkcs_blockstorage_volume.wiki_os' 00000000-0000-4000-8000-000000000212

terraform import 'vkcs_compute_instance.dc_01' 00000000-0000-4000-8000-000000000301
terraform import 'vkcs_blockstorage_volume.dc_01_os' 00000000-0000-4000-8000-000000000302

terraform import 'vkcs_compute_instance.gpu_llm_01' 00000000-0000-4000-8000-000000000401
terraform import 'vkcs_blockstorage_volume.gpu_llm_01_os' 00000000-0000-4000-8000-000000000402
terraform import 'vkcs_blockstorage_volume.gpu_llm_01_data' 00000000-0000-4000-8000-000000000403
terraform import 'vkcs_compute_volume_attach.gpu_llm_01_data' 00000000-0000-4000-8000-000000000401/00000000-0000-4000-8000-000000000403

terraform import 'vkcs_compute_instance.db_primary' 00000000-0000-4000-8000-000000000501
terraform import 'vkcs_blockstorage_volume.db_primary_os' 00000000-0000-4000-8000-000000000502
terraform import 'vkcs_blockstorage_volume.db_primary_data' 00000000-0000-4000-8000-000000000503
terraform import 'vkcs_compute_volume_attach.db_primary_data' 00000000-0000-4000-8000-000000000501/00000000-0000-4000-8000-000000000503

# 4) Reconcile HCL to state (NIC order, volume name, security_group_ids)
terraform plan -refresh-only
terraform plan
# Goal: No changes (or only intentional drift fixes in code)

# 5) If a provider quirk blocks a resource, isolate it (ignore_changes / disable file)
# instead of destroying production.
```

Attach import IDs for `vkcs_compute_volume_attach` are `instance_uuid/volume_uuid`.

Private run imported **200+** addresses with fail=0, then aligned HCL until plan exit 0. Apply was not used to "fix" the estate.
