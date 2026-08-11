# Era: legacy OpenStack / Selectel

Earlier client delivery on Selectel cloud:

- Dual providers: `selectel` + `openstack`
- S3-compatible remote state with `force_path_style` / skipped AWS validations
- Networks, bastion, kube masters as plain `openstack_*` resources

Sanitized; no real public subnets or account IDs from client estates.
