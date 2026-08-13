# Purpose: vm-identity.tf (sample of Windows identity / AD-class)
# Private estate had a large Windows slice (DC, federation, NPS, CA). One DC here.

# Console name: dc-01
# import: terraform import 'vkcs_compute_instance.dc_01' 00000000-0000-4000-8000-000000000301
# import: terraform import 'vkcs_blockstorage_volume.dc_01_os' 00000000-0000-4000-8000-000000000302
resource "vkcs_blockstorage_volume" "dc_01_os" {
  name              = "dc-01-os"
  size              = 80
  volume_type       = local.volume_types.ceph_ssd
  availability_zone = local.az.alt
  lifecycle {
    prevent_destroy = true
  }
}

resource "vkcs_compute_instance" "dc_01" {
  name               = "dc-01"
  flavor_name        = local.flavors.std_2_4
  availability_zone  = local.az.alt
  security_group_ids = [local.sg_ids.default]
  block_device {
    uuid                  = vkcs_blockstorage_volume.dc_01_os.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }
  network {
    uuid        = local.networks.office
    fixed_ip_v4 = "10.10.1.10"
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
