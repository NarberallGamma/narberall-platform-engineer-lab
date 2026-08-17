# Purpose: ecs-teleport.tf
# New VM after the import: prevent_destroy only, no brownfield ignore_changes.
# key_pair applies only on create. Terraform does not push a key onto an existing host.

resource "sbercloud_compute_instance" "teleport_db_prod" {
  name                  = "teleport-db-prod-01"
  flavor_id             = local.flavors.c6nl_xlarge_2
  image_id              = local.images.ubuntu_24_04
  key_pair              = local.key_pairs.ecs_prod
  security_group_ids    = [local.sg_ids.ngfw_untrust]
  availability_zone     = local.az.a
  description           = "Teleport DB agent for project-a prod"
  enterprise_project_id = "0"
  system_disk_type      = local.volume_types.essd
  system_disk_size      = 20
  network {
    uuid = local.subnets.prod
  }
  lifecycle {
    prevent_destroy = true
  }
}

output "teleport_db_prod_info" {
  description = "Teleport DB agent prod (created after import, not imported)"
  value = {
    instance_id       = sbercloud_compute_instance.teleport_db_prod.id
    instance_name     = sbercloud_compute_instance.teleport_db_prod.name
    flavor_id         = sbercloud_compute_instance.teleport_db_prod.flavor_id
    private_ip        = sbercloud_compute_instance.teleport_db_prod.network[0].fixed_ip_v4
    public_ip         = sbercloud_compute_instance.teleport_db_prod.public_ip
    status            = sbercloud_compute_instance.teleport_db_prod.status
    availability_zone = sbercloud_compute_instance.teleport_db_prod.availability_zone
    key_pair          = local.key_pairs.ecs_prod
  }
}
