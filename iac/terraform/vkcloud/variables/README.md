# Catalog module (maps)

Child module for the deploy root. Maps are `variable` defaults (overridable via tfvars).

Root wires them as:

```hcl
module "catalog" {
  source = "./variables"
}

locals {
  networks = module.catalog.networks
}
```

Keys in this public slice: `office`, `app`, `db`, `ext`.  
Duplicate empty Neutron nets in the private estate were renamed in console (`*_old`) so instance import could resolve the working nets by name. Those duplicates are not published here.

Do not run terraform from this directory alone.
