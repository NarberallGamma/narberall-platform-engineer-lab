resource "aws_instance" "edge_proxy" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = module.vpc.private_subnets[1]
  private_ip                  = "10.32.1.20"
  vpc_security_group_ids      = [aws_security_group.infra.id]
  associate_public_ip_address = false
  ebs_optimized               = true
  key_name                    = "tfadm-example"

  tags = {
    Name    = "edge-proxy"
    Service = "proxy"
    Group   = "staging"
  }

  user_data = templatefile("${path.module}/templates/init.tmpl", { vm_name = "edge-proxy" })

  lifecycle {
    ignore_changes = [user_data, ami, associate_public_ip_address]
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = false
  }
}

resource "aws_eip" "edge_proxy" {
  instance   = aws_instance.edge_proxy.id
  depends_on = [aws_instance.edge_proxy]
  tags       = { Name = "edge-proxy" }
}
