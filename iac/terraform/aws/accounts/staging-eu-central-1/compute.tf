module "common" {
  source = "../modules/common"
}

resource "aws_instance" "gitlab" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "m5a.xlarge"
  subnet_id                   = module.vpc.private_subnets[0]
  private_ip                  = "10.10.0.50"
  vpc_security_group_ids      = [aws_security_group.graph.id]
  associate_public_ip_address = true
  ebs_optimized               = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "gitlab" })

  tags = {
    Name    = "gitlab"
    Service = "gitlab"
    Group   = "staging"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 100
    volume_type           = "gp2"
    delete_on_termination = false
  }

  volume_tags = {
    Snapshot = "staging"
  }
}

resource "aws_eip" "gitlab" {
  instance   = aws_instance.gitlab.id
  depends_on = [aws_instance.gitlab]
  tags       = { Name = "gitlab" }
}

resource "aws_instance" "ws_proxy" {
  ami                         = module.common.ubuntu_24_ami
  instance_type               = "t3.small"
  subnet_id                   = module.vpc.private_subnets[0]
  private_ip                  = "10.10.0.60"
  vpc_security_group_ids      = [aws_security_group.graph.id]
  associate_public_ip_address = true
  ebs_optimized               = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "ws-proxy" })

  tags = {
    Name    = "ws-proxy"
    Service = "ws-proxy"
    Group   = "staging"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

resource "aws_eip" "ws_proxy" {
  instance   = aws_instance.ws_proxy.id
  depends_on = [aws_instance.ws_proxy]
}

resource "aws_instance" "sql_proxy" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.sql_proxy.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "sql-proxy-staging" })

  tags = {
    Name    = "sql-proxy-staging"
    Service = "sql-proxy"
    Group   = "staging"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

resource "aws_eip" "sql_proxy" {
  instance   = aws_instance.sql_proxy.id
  depends_on = [aws_instance.sql_proxy]
}

resource "aws_instance" "hrm" {
  ami                         = module.common.ubuntu_ami
  instance_type               = "t3a.small"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.hrm.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "hrm-app" })

  tags = {
    Name    = "hrm-app"
    Service = "hrm"
    Group   = "staging"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

resource "aws_eip" "hrm" {
  instance   = aws_instance.hrm.id
  depends_on = [aws_instance.hrm]
}

resource "aws_instance" "backup" {
  ami                         = module.common.ubuntu_24_ami
  instance_type               = "t3.small"
  subnet_id                   = module.vpc.private_subnets[0]
  private_ip                  = "10.10.0.70"
  vpc_security_group_ids      = [aws_security_group.default_ops.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "backup-stage" })

  tags = {
    Name = "backup-stage"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  root_block_device {
    volume_size = 30
  }
}

resource "aws_ebs_volume" "backup" {
  availability_zone = "eu-central-1a"
  size              = 615
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
  count                       = 2
  ami                         = module.common.ubuntu_22_ami
  instance_type               = "t3.medium"
  subnet_id                   = module.vpc.private_subnets[0]
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
  count      = 2
  instance   = aws_instance.kube_worker_static[count.index].id
  depends_on = [aws_instance.kube_worker_static]
}
