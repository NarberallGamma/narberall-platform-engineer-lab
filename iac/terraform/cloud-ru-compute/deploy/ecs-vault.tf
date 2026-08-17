# Purpose: ecs-vault.tf (Vault ECS)

# Console name: vault-dev-01
# import: terraform import sbercloud_compute_instance.vault_dev 00000000-0000-4000-8000-000000000403
# import: terraform import sbercloud_evs_volume.vault_dev__vol0 00000000-0000-4000-8000-000000000503
resource "sbercloud_evs_volume" "vault_dev__vol0" {
  name              = "vault-dev-data"
  size              = 40
  volume_type       = local.volume_types.sas
  availability_zone = local.az.a
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image_id]
  }
}

resource "sbercloud_compute_instance" "vault_dev" {
  name               = "vault-dev-01"
  flavor_id          = local.flavors.s7n_large_2
  image_id           = local.images.ubuntu_24_04
  security_group_ids = [local.sg_ids.ngfw_untrust]
  availability_zone  = local.az.a
  system_disk_type   = local.volume_types.sas
  system_disk_size   = 40
  network {
    uuid        = local.subnets.dev
    fixed_ip_v4 = "10.10.4.20"
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      image_id,
      user_data,
      data_disks,
      key_pair,
      metadata,
      tags,
      system_disk_id,
      volume_attached,
      power_action,
      charging_mode,
      delete_eip_on_termination,
      stop_before_destroy,
    ]
  }
}

# Console name: vault-prod-01
# import: terraform import sbercloud_compute_instance.vault_prod 00000000-0000-4000-8000-000000000404
# import: terraform import sbercloud_evs_volume.vault_prod__vol0 00000000-0000-4000-8000-000000000504
resource "sbercloud_evs_volume" "vault_prod__vol0" {
  name              = "vault-prod-01"
  size              = 40
  volume_type       = local.volume_types.sas
  availability_zone = local.az.a
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image_id]
  }
}

resource "sbercloud_compute_instance" "vault_prod" {
  name               = "vault-prod-01"
  flavor_id          = local.flavors.s7n_large_2
  image_id           = local.images.ubuntu_24_04
  security_group_ids = [local.sg_ids.ngfw_untrust]
  availability_zone  = local.az.a
  system_disk_type   = local.volume_types.sas
  system_disk_size   = 40
  network {
    uuid        = local.subnets.prod
    fixed_ip_v4 = "10.10.0.20"
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      image_id,
      user_data,
      data_disks,
      key_pair,
      metadata,
      tags,
      system_disk_id,
      volume_attached,
      power_action,
      charging_mode,
      delete_eip_on_termination,
      stop_before_destroy,
    ]
  }
}
