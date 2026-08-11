output "instance_id" { value = aws_instance.db.id }
output "private_ip" { value = aws_instance.db.private_ip }
output "eip" { value = aws_eip.db.public_ip }
