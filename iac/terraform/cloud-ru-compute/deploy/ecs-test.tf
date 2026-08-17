# Purpose: ecs-test.tf (stopped test ECS). Not Teleport, not NGFW.

# Console name: ecs-test-prod-01
# import: terraform import sbercloud_compute_instance.ecs_test_prod 00000000-0000-4000-8000-000000000409
# import: terraform import sbercloud_evs_volume.ecs_test_prod__vol0 00000000-0000-4000-8000-000000000509
resource "sbercloud_evs_volume" "ecs_test_prod__vol0" {
  name              = "ecs-test-prod-01"
  size              = 40
  volume_type       = local.volume_types.sas
  availability_zone = local.az.a
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image_id]
  }
}

resource "sbercloud_compute_instance" "ecs_test_prod" {
  name               = "ecs-test-prod-01"
  flavor_id          = local.flavors.s7n_medium_2
  image_id           = local.images.ubuntu_24_04
  security_group_ids = [local.sg_ids.default]
  availability_zone  = local.az.a
  system_disk_type   = local.volume_types.sas
  system_disk_size   = 40
  network {
    uuid        = local.subnets.prod
    fixed_ip_v4 = "10.10.0.50"
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

# Console name: ecs-test-preprod-01
# import: terraform import sbercloud_compute_instance.ecs_test_preprod 00000000-0000-4000-8000-000000000410
# import: terraform import sbercloud_evs_volume.ecs_test_preprod__vol0 00000000-0000-4000-8000-000000000510
resource "sbercloud_evs_volume" "ecs_test_preprod__vol0" {
  name              = "ecs-test-preprod-01"
  size              = 40
  volume_type       = local.volume_types.sas
  availability_zone = local.az.a
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image_id]
  }
}

resource "sbercloud_compute_instance" "ecs_test_preprod" {
  name               = "ecs-test-preprod-01"
  flavor_id          = local.flavors.s7n_medium_2
  image_id           = local.images.ubuntu_24_04
  security_group_ids = [local.sg_ids.default]
  availability_zone  = local.az.a
  system_disk_type   = local.volume_types.sas
  system_disk_size   = 40
  network {
    uuid        = local.subnets.preprod
    fixed_ip_v4 = "10.10.16.50"
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
