resource "aws_instance" "db" {
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = true
  ebs_optimized               = true

  user_data = templatefile("${path.module}/../../templates/init.tmpl", { vm_name = var.name })

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = false
  }

  lifecycle {
    ignore_changes = [user_data, ami, associate_public_ip_address]
  }

  tags = { Name = var.name }
}

resource "aws_eip" "db" {
  instance   = aws_instance.db.id
  depends_on = [aws_instance.db]
  tags       = { Name = var.name }
}

resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.db.availability_zone
  type              = var.storage_volume_type
  size              = var.storage_volume_size
  tags              = { Name = "${var.name}-storage" }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.db.id
}
