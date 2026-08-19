resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = module.vpc.public_subnets[0]
  private_ip                  = "10.32.100.10"
  vpc_security_group_ids      = [aws_security_group.infra.id]
  associate_public_ip_address = true
  ebs_optimized               = true
  key_name                    = "tfadm-example"

  tags = {
    Name    = "bastion"
    Service = "bastion"
    Group   = "staging"
  }

  user_data = templatefile("${path.module}/templates/init.tmpl", { vm_name = "bastion" })

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = false
  }
}

resource "aws_eip" "bastion" {
  instance   = aws_instance.bastion.id
  depends_on = [aws_instance.bastion]
  tags       = { Name = "bastion" }
}
