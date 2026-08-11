data "sbercloud_vpc" "prod_db_vpc" {
  id = var.prod_db_vpc_id
}

data "sbercloud_vpc_subnet" "prod_db_subnet" {
  id = var.prod_db_subnet_id
}

resource "sbercloud_rds_instance" "prod_postgresql" {
  name              = "project-a-prod-postgresql-15"
  flavor            = "rds.pg.x1.xlarge.4.ha"
  vpc_id            = data.sbercloud_vpc.prod_db_vpc.id
  subnet_id         = data.sbercloud_vpc_subnet.prod_db_subnet.id
  security_group_id = var.prod_security_group_id

  availability_zone = [
    "ru-example-1a",
    "ru-example-1b",
  ]

  ha_replication_mode = "async"

  db {
    type     = "PostgreSQL"
    version  = "15"
    password = var.prod_db_password
  }

  volume {
    type = "ESSD"
    size = 500
  }

  backup_strategy {
    start_time = "22:00-23:00"
    keep_days  = 14
    period     = "1,2,3,4,5,6,7"
  }

  maintain_begin = "03:00"
  maintain_end   = "04:00"

  lifecycle {
    ignore_changes = [db]
  }

  tags = {
    env     = "prod"
    project = "project-a"
  }
}
