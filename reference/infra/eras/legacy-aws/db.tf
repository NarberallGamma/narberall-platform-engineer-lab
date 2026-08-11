module "postgres_01" {
  source = "./modules/db_instance"

  name               = "postgres-01"
  ami                = data.aws_ami.ubuntu.id
  instance_type      = "r5.large"
  key_name           = "tfadm-example"
  subnet_id          = module.vpc.private_subnets[1]
  security_group_ids = [aws_security_group.infra.id]
  root_volume_size   = 40
  storage_volume_size = 200
}
