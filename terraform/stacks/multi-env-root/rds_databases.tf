# Logical databases and DB user on managed PostgreSQL.

variable "prod_app_db_password" {
  type      = string
  sensitive = true
}

resource "sbercloud_rds_pg_account" "app" {
  instance_id = sbercloud_rds_instance.prod_postgresql.id
  name        = "app_user"
  password    = var.prod_app_db_password

  lifecycle {
    ignore_changes = [password]
  }
}

resource "sbercloud_rds_pg_database" "api" {
  instance_id = sbercloud_rds_instance.prod_postgresql.id
  name        = "app_api"
  owner       = sbercloud_rds_pg_account.app.name
}

resource "sbercloud_rds_pg_database" "auth" {
  instance_id = sbercloud_rds_instance.prod_postgresql.id
  name        = "app_auth"
  owner       = sbercloud_rds_pg_account.app.name
}

resource "sbercloud_rds_pg_database" "keycloak" {
  instance_id = sbercloud_rds_instance.prod_postgresql.id
  name        = "keycloak"
  owner       = sbercloud_rds_pg_account.app.name
}
