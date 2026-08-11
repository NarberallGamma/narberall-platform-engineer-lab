# Managed Kafka (DMS) + topics + users. Names/topics are generic.

variable "prod_kafka_password" {
  type      = string
  sensitive = true
}

resource "sbercloud_dms_kafka_instance" "prod" {
  name              = "project-a-prod-kafka"
  description       = "Kafka cluster for production"
  vpc_id            = sbercloud_vpc.prod.id
  network_id        = sbercloud_vpc_subnet.prod_app.id
  security_group_id = var.prod_security_group_id

  availability_zones = ["ru-example-1a", "ru-example-1b", "ru-example-1c"]
  engine_version     = "2.7"
  flavor_id          = "c6.4u8g.cluster"
  storage_spec_code  = "dms.physical.storage.ultra.v2"
  storage_space      = 300
  broker_num         = 3

  access_user = "kafka_user"
  password    = var.prod_kafka_password
  ssl_enable  = true

  retention_policy  = "time_base"
  enable_auto_topic = false
  maintain_begin    = "02:00:00"
  maintain_end      = "06:00:00"

  tags = {
    env     = "prod"
    project = "project-a"
    service = "kafka"
  }

  lifecycle {
    ignore_changes = [password]
  }
}

resource "sbercloud_dms_kafka_topic" "events" {
  instance_id        = sbercloud_dms_kafka_instance.prod.id
  name               = "app.events"
  partitions         = 10
  replicas           = 3
  aging_time         = 72
  sync_replication   = true
}

resource "sbercloud_dms_kafka_topic" "audit" {
  instance_id      = sbercloud_dms_kafka_instance.prod.id
  name             = "app.audit"
  partitions       = 6
  replicas         = 3
  aging_time       = 168
  sync_replication = true
}

resource "sbercloud_dms_kafka_user" "app" {
  instance_id = sbercloud_dms_kafka_instance.prod.id
  name        = "app_user"
  password    = var.prod_kafka_password

  lifecycle {
    ignore_changes = [password]
  }
}
