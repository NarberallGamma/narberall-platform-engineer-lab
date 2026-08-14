# Catalog maps

Keys, not raw URNs, in `vm-*.tf`:

```hcl
storage_policy = local.storage.policy
network_name   = local.networks.org_routed
```

Disk sizes stay in the VM file. IOPS: `min(size_GB * iops_per_gb, iops_max)` from the live storage profile (fallback values in `storage.tf`).
