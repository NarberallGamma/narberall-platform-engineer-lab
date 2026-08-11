# Brownfield import checklist (fake IDs)

Use after writing Terraform that matches live resources.

```bash
# 1) Inventory / audit (read-only) — private tooling; not in this repo
# 2) Write resource blocks that match reality
# 3) Import (examples with fake IDs)

terraform import 'sbercloud_vpc.dev' vpc-aaaa1111
terraform import 'sbercloud_vpc_subnet.dev_app' subnet-bbbb2222

# 4) Reconcile
terraform plan -refresh-only
terraform plan
# Goal: No changes (or only intentional drift fixes in code)

# 5) If a provider bug blocks a resource, isolate it (disable file / state rm)
# instead of destroying production.
```

Never commit real resource IDs, tenant IDs, or state files.
