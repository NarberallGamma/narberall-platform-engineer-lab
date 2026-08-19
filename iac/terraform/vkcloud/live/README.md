# Terragrunt unit: security / metrics VM

Sibling of the brownfield `vm-*.tf` import root. This unit **creates** a host from an image data source (cloud-init SSH keys, boot volume, `ignore_changes` on image UUID).

Private delivery used the same module + S3-compatible remote state (Hotbox-class) and an ephemeral Keystone token in CI. This lab keeps fake project IDs and an empty key list.

Module: [`../modules/compute_instance/`](../modules/compute_instance/)
