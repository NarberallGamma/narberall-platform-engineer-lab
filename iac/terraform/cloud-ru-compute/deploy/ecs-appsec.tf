# Purpose: ecs-appsec.tf (AppSec ECS in vpc-appsec)

# Console name: appsec-nessus-01
# import: terraform import sbercloud_compute_instance.appsec_nessus 00000000-0000-4000-8000-000000000405
# import: terraform import sbercloud_evs_volume.appsec_nessus__vol0 00000000-0000-4000-8000-000000000505
resource "sbercloud_evs_volume" "appsec_nessus__vol0" {
  name              = "appsec-nessus-01"
  size              = 50
  volume_type       = local.volume_types.sas
  availability_zone = local.az.a
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image_id]
  }
}

resource "sbercloud_compute_instance" "appsec_nessus" {
  name               = "appsec-nessus-01"
  flavor_id          = local.flavors.c7n_xlarge_2
  image_id           = local.images.debian_12
  security_group_ids = [local.sg_ids.platform]
  availability_zone  = local.az.a
  system_disk_type   = local.volume_types.sas
  system_disk_size   = 50
  network {
    uuid        = local.subnets.appsec
    fixed_ip_v4 = "10.10.8.10"
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

# Console name: appsec-semgrep-01
# import: terraform import sbercloud_compute_instance.appsec_semgrep 00000000-0000-4000-8000-000000000406
# import: terraform import sbercloud_evs_volume.appsec_semgrep__vol0 00000000-0000-4000-8000-000000000506
resource "sbercloud_evs_volume" "appsec_semgrep__vol0" {
  name              = "appsec-semgrep-01"
  size              = 20
  volume_type       = local.volume_types.sas
  availability_zone = local.az.a
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image_id]
  }
}

resource "sbercloud_compute_instance" "appsec_semgrep" {
  name               = "appsec-semgrep-01"
  flavor_id          = local.flavors.c7n_xlarge_2
  image_id           = local.images.debian_12
  security_group_ids = [local.sg_ids.platform]
  availability_zone  = local.az.a
  system_disk_type   = local.volume_types.sas
  system_disk_size   = 20
  network {
    uuid        = local.subnets.appsec
    fixed_ip_v4 = "10.10.8.20"
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

# Console name: appsec-dtrack-01
# import: terraform import sbercloud_compute_instance.appsec_dtrack 00000000-0000-4000-8000-000000000407
# import: terraform import sbercloud_evs_volume.appsec_dtrack__vol0 00000000-0000-4000-8000-000000000507
resource "sbercloud_evs_volume" "appsec_dtrack__vol0" {
  name              = "appsec-dtrack-01"
  size              = 50
  volume_type       = local.volume_types.essd
  availability_zone = local.az.a
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image_id]
  }
}

resource "sbercloud_compute_instance" "appsec_dtrack" {
  name               = "appsec-dtrack-01"
  flavor_id          = local.flavors.c7n_xlarge_2
  image_id           = local.images.debian_12
  security_group_ids = [local.sg_ids.platform, local.sg_ids.dependencytrack]
  availability_zone  = local.az.a
  system_disk_type   = local.volume_types.essd
  system_disk_size   = 50
  network {
    uuid        = local.subnets.appsec
    fixed_ip_v4 = "10.10.8.30"
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

# Console name: appsec-defectdojo-01
# import: terraform import sbercloud_compute_instance.appsec_defectdojo 00000000-0000-4000-8000-000000000408
# import: terraform import sbercloud_evs_volume.appsec_defectdojo__vol0 00000000-0000-4000-8000-000000000508
resource "sbercloud_evs_volume" "appsec_defectdojo__vol0" {
  name              = "appsec-defectdojo-01"
  size              = 40
  volume_type       = local.volume_types.essd
  availability_zone = local.az.a
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image_id]
  }
}

resource "sbercloud_compute_instance" "appsec_defectdojo" {
  name               = "appsec-defectdojo-01"
  flavor_id          = local.flavors.c7n_xlarge_2
  image_id           = local.images.debian_12
  security_group_ids = [local.sg_ids.defectdojo, local.sg_ids.platform]
  availability_zone  = local.az.a
  system_disk_type   = local.volume_types.essd
  system_disk_size   = 40
  network {
    uuid        = local.subnets.appsec
    fixed_ip_v4 = "10.10.8.40"
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
