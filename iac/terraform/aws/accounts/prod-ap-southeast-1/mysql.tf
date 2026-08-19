resource "aws_instance" "mysql_primary" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "m5.large"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mysql.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "mysql-primary" })

  tags = {
    Name    = "mysql-primary"
    Service = "mysql"
    Group   = "prod"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 500
    volume_type           = "gp3"
    delete_on_termination = false
  }
}

resource "aws_eip" "mysql_primary" {
  instance   = aws_instance.mysql_primary.id
  depends_on = [aws_instance.mysql_primary]
}

resource "aws_instance" "mysql_replica" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "m5.large"
  subnet_id                   = module.vpc.private_subnets[1]
  vpc_security_group_ids      = [aws_security_group.mysql.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "mysql-replica" })

  tags = {
    Name    = "mysql-replica"
    Service = "mysql"
    Group   = "prod"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 500
    volume_type           = "gp3"
    delete_on_termination = false
  }
}

resource "aws_eip" "mysql_replica" {
  instance   = aws_instance.mysql_replica.id
  depends_on = [aws_instance.mysql_replica]
}

resource "aws_ebs_volume" "mysql_binlogs" {
  availability_zone = "ap-southeast-1a"
  size              = 200
  type              = "gp3"
  tags              = { Name = "mysql-binlogs" }
}

resource "aws_volume_attachment" "mysql_binlogs" {
  device_name = "/dev/sdc"
  volume_id   = aws_ebs_volume.mysql_binlogs.id
  instance_id = aws_instance.mysql_primary.id
}

resource "aws_dlm_lifecycle_policy" "mysql_daily" {
  description        = "Daily snapshots of tagged MySQL volumes"
  execution_role_arn = "arn:aws:iam::000000000000:role/AWSDataLifecycleManagerDefaultRole"
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "2 weeks of daily snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["23:45"]
      }

      retain_rule {
        count = 14
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
      }

      copy_tags = false
    }

    target_tags = {
      Snapshot = "mysql"
    }
  }
}
