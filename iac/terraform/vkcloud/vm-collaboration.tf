# Purpose: vm-collaboration.tf (sample of Atlassian-class hosts)
# Private estate had a handful of these. Catalog keys only, fake import IDs.

# Console name: collab-app
# import: terraform import 'vkcs_compute_instance.collab_app' 00000000-0000-4000-8000-000000000201
# import: terraform import 'vkcs_blockstorage_volume.collab_app_os' 00000000-0000-4000-8000-000000000202
resource "vkcs_blockstorage_volume" "collab_app_os" {
  name              = "collab-app-os"
  size              = 120
  volume_type       = local.volume_types.high_iops
  availability_zone = local.az.edge
  lifecycle {
    prevent_destroy = true
  }
}

# import: terraform import 'vkcs_blockstorage_volume.collab_app_data' 00000000-0000-4000-8000-000000000203
resource "vkcs_blockstorage_volume" "collab_app_data" {
  name              = "collab-app-data"
  size              = 220
  volume_type       = local.volume_types.high_iops
  availability_zone = local.az.edge
  lifecycle {
    prevent_destroy = true
  }
}

resource "vkcs_compute_instance" "collab_app" {
  name               = "collab-app"
  flavor_name        = local.flavors.std_8_16
  availability_zone  = local.az.edge
  key_pair           = local.key_pairs.linux_ops
  security_group_ids = [local.sg_ids.default, local.sg_ids.app]
  block_device {
    uuid                  = vkcs_blockstorage_volume.collab_app_os.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }
  network {
    uuid        = local.networks.app
    fixed_ip_v4 = "10.10.2.10"
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

# import: terraform import 'vkcs_compute_volume_attach.collab_app_data' 00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000203
resource "vkcs_compute_volume_attach" "collab_app_data" {
  instance_id = vkcs_compute_instance.collab_app.id
  volume_id   = vkcs_blockstorage_volume.collab_app_data.id
  lifecycle {
    prevent_destroy = true
  }
}

# Console name: wiki
# import: terraform import 'vkcs_compute_instance.wiki' 00000000-0000-4000-8000-000000000211
# import: terraform import 'vkcs_blockstorage_volume.wiki_os' 00000000-0000-4000-8000-000000000212
resource "vkcs_blockstorage_volume" "wiki_os" {
  name              = "wiki-os"
  size              = 100
  volume_type       = local.volume_types.high_iops_ha
  availability_zone = local.az.core
  lifecycle {
    prevent_destroy = true
  }
}

resource "vkcs_compute_instance" "wiki" {
  name               = "wiki"
  flavor_name        = local.flavors.std_4_8
  availability_zone  = local.az.core
  key_pair           = local.key_pairs.linux_ops
  security_group_ids = [local.sg_ids.default, local.sg_ids.app]
  block_device {
    uuid                  = vkcs_blockstorage_volume.wiki_os.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }
  network {
    uuid        = local.networks.app
    fixed_ip_v4 = "10.10.2.11"
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
