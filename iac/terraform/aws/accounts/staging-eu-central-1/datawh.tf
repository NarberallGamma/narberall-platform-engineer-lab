resource "aws_instance" "datawh_mysql" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "t3.medium"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.datawh.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "datawh-mysql" })

  tags = {
    Name    = "datawh-mysql"
    Service = "datawh"
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

resource "aws_eip" "datawh_mysql" {
  instance   = aws_instance.datawh_mysql.id
  depends_on = [aws_instance.datawh_mysql]
}

resource "aws_instance" "datawh_postgres" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "t3.medium"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.datawh.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "datawh-postgres" })

  tags = {
    Name    = "datawh-postgres"
    Service = "datawh"
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

resource "aws_eip" "datawh_postgres" {
  instance   = aws_instance.datawh_postgres.id
  depends_on = [aws_instance.datawh_postgres]
}

resource "aws_instance" "airflow" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "t3.small"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.airflow.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "airflow" })

  tags = {
    Name    = "airflow"
    Service = "airflow"
    Group   = "staging"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

resource "aws_eip" "airflow" {
  instance   = aws_instance.airflow.id
  depends_on = [aws_instance.airflow]
}
