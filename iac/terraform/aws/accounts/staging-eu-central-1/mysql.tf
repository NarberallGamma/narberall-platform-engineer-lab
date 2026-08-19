resource "aws_instance" "mysql_reports" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "t3.small"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mysql.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "mysql-reports" })

  tags = {
    Name    = "mysql-reports"
    Service = "mysql"
    Group   = "staging"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 200
    volume_type           = "gp2"
    delete_on_termination = false
  }
}

resource "aws_eip" "mysql_reports" {
  instance   = aws_instance.mysql_reports.id
  depends_on = [aws_instance.mysql_reports]
}

resource "aws_instance" "mysql_stage" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "t3.small"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mysql.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "mysql-stage" })

  tags = {
    Name    = "mysql-stage"
    Service = "mysql"
    Group   = "staging"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 200
    volume_type           = "gp2"
    delete_on_termination = false
  }
}

resource "aws_eip" "mysql_stage" {
  instance   = aws_instance.mysql_stage.id
  depends_on = [aws_instance.mysql_stage]
}

resource "aws_instance" "mysql_stage_new" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "t3.small"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mysql.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "mysql-stage-new" })

  tags = {
    Name    = "mysql-stage-new"
    Service = "mysql"
    Group   = "staging"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 200
    volume_type           = "gp2"
    delete_on_termination = false
  }
}

resource "aws_eip" "mysql_stage_new" {
  instance   = aws_instance.mysql_stage_new.id
  depends_on = [aws_instance.mysql_stage_new]
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
