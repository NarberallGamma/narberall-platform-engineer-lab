resource "aws_instance" "vault" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "m5a.large"
  subnet_id              = module.vpc.private_subnets[2]
  private_ip             = "10.32.2.40"
  vpc_security_group_ids = [aws_security_group.infra.id]
  ebs_optimized          = true
  key_name               = "tfadm-example"

  tags = {
    Name    = "vault"
    Service = "vault"
    Group   = "staging"
  }

  user_data = templatefile("${path.module}/templates/init.tmpl", { vm_name = "vault" })

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = false
  }
}
