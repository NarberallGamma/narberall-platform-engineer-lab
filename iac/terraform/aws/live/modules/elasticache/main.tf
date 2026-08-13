variable "name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }

resource "aws_elasticache_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "this" {
  name   = var.name
  vpc_id = var.vpc_id
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = var.name
  description                = var.name
  node_type                  = "cache.t4g.small"
  num_cache_clusters         = 2
  engine                     = "redis"
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.this.id]
  automatic_failover_enabled = true
}
