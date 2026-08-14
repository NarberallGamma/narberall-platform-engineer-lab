# Read-only VCD audit

Same provider as the deploy slice. No `vcd_vapp_vm` create. Use to list catalogs, templates, Edge, org networks, and storage-profile IOPS before writing `vm-*.tf`.

State key (example): `vmware/audit/terraform.tfstate` in the same S3-compatible bucket as deploy.
