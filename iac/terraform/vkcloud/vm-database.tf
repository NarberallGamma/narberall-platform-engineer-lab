# Purpose: vm-database.tf (self-managed DB sample)
# Managed DBaaS members were inventoried and excluded from Nova import.

# Console name: db-primary
# import: terraform import 'vkcs_compute_instance.db_primary' 00000000-0000-4000-8000-000000000501
# import: terraform import 'vkcs_blockstorage_volume.db_primary_os' 00000000-0000-4000-8000-000000000502
resource "vkcs_blockstorage_volume" "db_primary_os" {
  name              = "db-primary-os"
  size              = 80
  volume_type       = local.volume_types.high_iops_ha
  availability_zone = local.az.core
  lifecycle {
    prevent_destroy = true
  }
}

# import: terraform import 'vkcs_blockstorage_volume.db_primary_data' 00000000-0000-4000-8000-000000000503
resource "vkcs_blockstorage_volume" "db_primary_data" {
  name              = "db-primary-data"
  size              = 500
  volume_type       = local.volume_types.high_iops_ha
  availability_zone = local.az.core
  lifecycle {
    prevent_destroy = true
  }
}

resource "vkcs_compute_instance" "db_primary" {
  name               = "db-primary"
  flavor_name        = local.flavors.std_8_16
  availability_zone  = local.az.core
  key_pair           = local.key_pairs.linux_ops
  security_group_ids = [local.sg_ids.default, local.sg_ids.db]
  block_device {
    uuid                  = vkcs_blockstorage_volume.db_primary_os.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }
  network {
    uuid        = local.networks.db
    fixed_ip_v4 = "10.10.3.10"
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      block_device,
      flavor_name,
      flavor_id,
      force_delete,
      stop_before_destroy,
    ]
  }
}

# import: terraform import 'vkcs_compute_volume_attach.db_primary_data' 00000000-0000-4000-8000-000000000501/00000000-0000-4000-8000-000000000503
resource "vkcs_compute_volume_attach" "db_primary_data" {
  instance_id = vkcs_compute_instance.db_primary.id
  volume_id   = vkcs_blockstorage_volume.db_primary_data.id
  lifecycle {
    prevent_destroy = true
  }
}
