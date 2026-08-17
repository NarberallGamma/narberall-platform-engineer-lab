variable "key_pairs" {
  description = "ECS key pair names. legacy_dev is a leftover on one imported GitLab host. ecs_* are project deploy keys for new VMs."
  type        = map(string)
  default = {
    legacy_dev   = "legacy-dev"
    ecs_dev      = "project-a-dev-ecs-key"
    ecs_preprod  = "project-a-preprod-ecs-key"
    ecs_prod     = "project-a-prod-ecs-key"
  }
}
