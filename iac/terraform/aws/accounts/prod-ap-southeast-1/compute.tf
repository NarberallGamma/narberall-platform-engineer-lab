module "common" {
  source = "../modules/common"
}

resource "aws_instance" "bastion" {
  ami                         = module.common.ubuntu_24_ami
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.default_ops.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "bastion" })

  tags = {
    Name    = "bastion"
    Service = "bastion"
    Group   = "prod"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

resource "aws_eip" "bastion" {
  instance   = aws_instance.bastion.id
  depends_on = [aws_instance.bastion]
}

resource "aws_instance" "reports_win" {
  ami                         = module.common.windows_server_2016_ami
  instance_type               = "t3.large"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.default_ops.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  get_password_data           = true
  user_data = templatefile("${path.module}/../templates/init-win.tmpl", {
    windows_username = var.windows_username
    windows_password = var.windows_password
  })

  tags = {
    Name    = "reports-win"
    Service = "reports"
    Group   = "prod"
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

resource "aws_eip" "reports_win" {
  instance   = aws_instance.reports_win.id
  depends_on = [aws_instance.reports_win]
}

resource "aws_instance" "graph" {
  count                       = 2
  ami                         = module.common.ubuntu_22_ami
  instance_type               = "r5.large"
  subnet_id                   = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  vpc_security_group_ids      = [aws_security_group.graph.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = format("graph-%d", count.index + 1) })

  tags = {
    Name    = format("graph-%d", count.index + 1)
    Service = "graph"
    Group   = "prod"
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

resource "aws_eip" "graph" {
  count      = 2
  instance   = aws_instance.graph[count.index].id
  depends_on = [aws_instance.graph]
}

resource "aws_instance" "sql_proxy" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "t3.small"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.sql_proxy.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "sql-proxy-prod" })

  tags = {
    Name    = "sql-proxy-prod"
    Service = "sql-proxy"
    Group   = "prod"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

resource "aws_eip" "sql_proxy" {
  instance   = aws_instance.sql_proxy.id
  depends_on = [aws_instance.sql_proxy]
}

resource "aws_instance" "backup" {
  ami                         = module.common.ubuntu_24_ami
  instance_type               = "t3.small"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.default_ops.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "backup-prod" })

  tags = {
    Name = "backup-prod"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  root_block_device {
    volume_size = 30
  }
}

resource "aws_ebs_volume" "backup" {
  availability_zone = "ap-southeast-1a"
  size              = 1024
  type              = "st1"
}

resource "aws_volume_attachment" "backup" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.backup.id
  instance_id = aws_instance.backup.id
}

resource "aws_eip" "backup" {
  instance   = aws_instance.backup.id
  depends_on = [aws_instance.backup]
}

resource "aws_instance" "kube_worker_static" {
  count                       = 3
  ami                         = module.common.ubuntu_22_ami
  instance_type               = "m5.large"
  subnet_id                   = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  vpc_security_group_ids      = [aws_security_group.default_ops.id]
  iam_instance_profile        = "kube-node"
  associate_public_ip_address = true
  source_dest_check           = false
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = format("kube-worker-static-%d", count.index + 1) })

  tags = {
    Name                         = format("kube-worker-static-%d", count.index + 1)
    "kubernetes.io/cluster/kube" = "shared"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

resource "aws_eip" "kube_worker_static" {
  count      = 3
  instance   = aws_instance.kube_worker_static[count.index].id
  depends_on = [aws_instance.kube_worker_static]
}

resource "aws_instance" "cms" {
  ami                         = module.common.ubuntu_22_ami
  instance_type               = "t3.medium"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "cms" })

  tags = {
    Name    = "cms"
    Service = "cms"
    Group   = "prod"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 50
    volume_type           = "gp2"
    delete_on_termination = false
  }
}

resource "aws_eip" "cms" {
  instance   = aws_instance.cms.id
  depends_on = [aws_instance.cms]
}
