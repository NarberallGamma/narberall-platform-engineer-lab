# Pattern from multi-account / multi-region AWS delivery: RDS MySQL next to app networking.
# Instance identifiers and CIDRs are fake.

resource "aws_db_subnet_group" "app" {
  name       = "project-a-app"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "project-a-app"
  }
}

resource "aws_db_instance" "mysql" {
  identifier             = "project-a-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.medium"
  allocated_storage      = 100
  db_subnet_group_name   = aws_db_subnet_group.app.name
  vpc_security_group_ids = [aws_security_group.mysql.id]
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = true
  multi_az               = true
  storage_encrypted      = true

  lifecycle {
    ignore_changes = [password]
  }
}

resource "aws_security_group" "mysql" {
  name   = "project-a-mysql"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}
