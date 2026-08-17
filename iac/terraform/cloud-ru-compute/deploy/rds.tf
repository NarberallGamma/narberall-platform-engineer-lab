# Purpose: rds.tf (PostgreSQL). db.password is required by the provider; ignore_changes on db.
# availability_zone is ForceNew and empty in imported state; AZ from inventory:
#   prod/preprod: local.az.a + local.az.b; dev: local.az.a

# import: terraform import sbercloud_rds_instance.prod_01 00000000000000000000000000000001in03
resource "sbercloud_rds_instance" "prod_01" {
  name                = "prod-01"
  flavor              = local.flavors.rds_pg_n1_xlarge_4_ha
  vpc_id              = local.vpcs.prod
  subnet_id           = local.subnets.prod
  security_group_id   = local.sg_ids.ngfw_untrust
  availability_zone   = [local.az.a, local.az.b]
  ha_replication_mode = "async"
  time_zone           = "UTC+03:00"
  db {
    type     = "PostgreSQL"
    version  = "17"
    password = var.rds_db_password
    port     = 5432
  }
  volume {
    type = local.volume_types.cloudssd
    size = 40
  }
  backup_strategy {
    start_time = "00:00-01:00"
    keep_days  = 7
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      db,
      parameters,
      nodes,
      maintain_begin,
      maintain_end,
      charging_mode,
      ssl_enable,
      availability_zone,
      backup_strategy,
      volume,
      enterprise_project_id,
    ]
  }
}

# import: terraform import sbercloud_rds_instance.preprod_01 00000000000000000000000000000002in03
resource "sbercloud_rds_instance" "preprod_01" {
  name                = "preprod-01"
  flavor              = local.flavors.rds_pg_x1_xlarge_4_ha
  vpc_id              = local.vpcs.preprod
  subnet_id           = local.subnets.preprod
  security_group_id   = local.sg_ids.ngfw_untrust
  availability_zone   = [local.az.a, local.az.b]
  ha_replication_mode = "async"
  time_zone           = "UTC+03:00"
  db {
    type     = "PostgreSQL"
    version  = "17"
    password = var.rds_db_password
    port     = 5432
  }
  volume {
    type = local.volume_types.cloudssd
    size = 40
  }
  backup_strategy {
    start_time = "00:00-01:00"
    keep_days  = 7
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      db,
      parameters,
      nodes,
      maintain_begin,
      maintain_end,
      charging_mode,
      ssl_enable,
      availability_zone,
      backup_strategy,
      volume,
      enterprise_project_id,
    ]
  }
}

# import: terraform import sbercloud_rds_instance.dev_01 00000000000000000000000000000003in03
resource "sbercloud_rds_instance" "dev_01" {
  name              = "dev-01"
  flavor            = local.flavors.rds_pg_x1_xlarge_4
  vpc_id            = local.vpcs.dev
  subnet_id         = local.subnets.dev
  security_group_id = local.sg_ids.ngfw_untrust
  availability_zone = [local.az.a]
  time_zone         = "UTC+03:00"
  db {
    type     = "PostgreSQL"
    version  = "17"
    password = var.rds_db_password
    port     = 5432
  }
  volume {
    type = local.volume_types.cloudssd
    size = 40
  }
  backup_strategy {
    start_time = "23:00-00:00"
    keep_days  = 7
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      db,
      parameters,
      nodes,
      maintain_begin,
      maintain_end,
      charging_mode,
      ssl_enable,
      availability_zone,
      backup_strategy,
      volume,
      enterprise_project_id,
    ]
  }
}
