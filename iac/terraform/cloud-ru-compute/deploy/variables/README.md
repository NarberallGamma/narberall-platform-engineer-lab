# Catalog maps (child module)

Maps of existing IDs and public flavor / AZ / volume-type names. No `resource` blocks.

VPC and subnet UUIDs come from a sibling Terragrunt live. This module only exposes them as keys for CCE / RDS / ECS files.

IDs in this lab are fake (`00000000-0000-4000-8000-...`). CIDRs are documentation ranges (`10.10.x.x`).
