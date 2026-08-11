data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "gitlab" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "m5a.xlarge"
  subnet_id                   = module.vpc.private_subnets[0]
  private_ip                  = "10.32.0.50"
  vpc_security_group_ids      = [aws_security_group.infra.id]
  associate_public_ip_address = true
  ebs_optimized               = true
  key_name                    = "tfadm-example"

  tags = {
    Name    = "gitlab"
    Service = "gitlab"
    Group   = "staging"
  }

  user_data = templatefile("${path.module}/templates/init.tmpl", { vm_name = "gitlab" })

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
