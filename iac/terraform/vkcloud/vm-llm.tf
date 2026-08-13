# Purpose: vm-llm.tf (GPU inference sample)
# Private estate: one V100-class VM. Boot volume + extra data disk.

# Console name: gpu-llm-01
# import: terraform import 'vkcs_compute_instance.gpu_llm_01' 00000000-0000-4000-8000-000000000401
# import: terraform import 'vkcs_blockstorage_volume.gpu_llm_01_os' 00000000-0000-4000-8000-000000000402
resource "vkcs_blockstorage_volume" "gpu_llm_01_os" {
  size              = 25
  volume_type       = local.volume_types.high_iops_ha
  availability_zone = local.az.gpu
  lifecycle {
    prevent_destroy = true
  }
}

# import: terraform import 'vkcs_blockstorage_volume.gpu_llm_01_data' 00000000-0000-4000-8000-000000000403
resource "vkcs_blockstorage_volume" "gpu_llm_01_data" {
  name              = "gpu-llm-01-data"
  size              = 50
  volume_type       = local.volume_types.high_iops_ha
  availability_zone = local.az.gpu
  lifecycle {
    prevent_destroy = true
  }
}

resource "vkcs_compute_instance" "gpu_llm_01" {
  name               = "gpu-llm-01"
  flavor_name        = local.flavors.gpu_v100
  availability_zone  = local.az.gpu
  key_pair           = local.key_pairs.gpu_lab
  security_group_ids = [local.sg_ids.default, local.sg_ids.app]
  block_device {
    uuid                  = vkcs_blockstorage_volume.gpu_llm_01_os.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }
  network {
    uuid        = local.networks.app
    fixed_ip_v4 = "10.10.2.18"
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

# import: terraform import 'vkcs_compute_volume_attach.gpu_llm_01_data' 00000000-0000-4000-8000-000000000401/00000000-0000-4000-8000-000000000403
resource "vkcs_compute_volume_attach" "gpu_llm_01_data" {
  instance_id = vkcs_compute_instance.gpu_llm_01.id
  volume_id   = vkcs_blockstorage_volume.gpu_llm_01_data.id
  lifecycle {
    prevent_destroy = true
  }
}
