# Purpose: ecs-gitlab.tf (GitLab ECS, not CCE nodes, not NGFW)
# Catalog: local.subnets / sg_ids / flavors / az / volume_types / images / key_pairs

# Console name: gitlab-dev-01
# import: terraform import sbercloud_compute_instance.gitlab_dev 00000000-0000-4000-8000-000000000401
# import: terraform import sbercloud_evs_volume.gitlab_dev__vol0 00000000-0000-4000-8000-000000000501
resource "sbercloud_evs_volume" "gitlab_dev__vol0" {
  name              = "gitlab-dev-data"
  size              = 400
  volume_type       = local.volume_types.sas
  availability_zone = local.az.a
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image_id]
  }
}

resource "sbercloud_compute_instance" "gitlab_dev" {
  name               = "gitlab-dev-01"
  flavor_id          = local.flavors.s7n_2xlarge_2
  image_id           = local.images.ubuntu_24_04
  key_pair           = local.key_pairs.legacy_dev
  security_group_ids = [local.sg_ids.ngfw_untrust]
  availability_zone  = local.az.a
  system_disk_type   = local.volume_types.sas
  system_disk_size   = 400
  network {
    uuid        = local.subnets.dev
    fixed_ip_v4 = "10.10.4.10"
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

# Console name: gitlab-prod-01
# import: terraform import sbercloud_compute_instance.gitlab_prod 00000000-0000-4000-8000-000000000402
# import: terraform import sbercloud_evs_volume.gitlab_prod__vol0 00000000-0000-4000-8000-000000000502
resource "sbercloud_evs_volume" "gitlab_prod__vol0" {
  name              = "gitlab-prod-01"
  size              = 40
  volume_type       = local.volume_types.sas
  availability_zone = local.az.a
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image_id]
  }
}

resource "sbercloud_compute_instance" "gitlab_prod" {
  name               = "gitlab-prod-01"
  flavor_id          = local.flavors.s7n_2xlarge_2
  image_id           = local.images.ubuntu_24_04
  security_group_ids = [local.sg_ids.ngfw_untrust]
  availability_zone  = local.az.a
  system_disk_type   = local.volume_types.sas
  system_disk_size   = 40
  network {
    uuid        = local.subnets.prod
    fixed_ip_v4 = "10.10.0.10"
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
