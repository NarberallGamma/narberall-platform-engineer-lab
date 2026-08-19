resource "aws_instance" "ci_runner" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "m5a.large"
  subnet_id              = module.vpc.private_subnets[0]
  private_ip             = "10.32.0.30"
  vpc_security_group_ids = [aws_security_group.infra.id]
  ebs_optimized          = true
  key_name               = "tfadm-example"

  tags = {
    Name    = "ci-runner"
    Service = "gitlab-runner"
    Group   = "staging"
  }

  user_data = templatefile("${path.module}/templates/init.tmpl", { vm_name = "ci-runner" })

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = 80
    volume_type           = "gp3"
    delete_on_termination = false
  }
}
