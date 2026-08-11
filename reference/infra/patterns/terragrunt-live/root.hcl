# Root Terragrunt config (sanitized example).
# Credentials and real bucket names stay out of git: use env vars and *.example secrets.

locals {
  access_key     = get_env("CLOUD_ACCESS_KEY", "")
  secret_key     = get_env("CLOUD_SECRET_KEY", "")
  security_token = get_env("CLOUD_STS", "")
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_name   = local.env_vars.locals.project_name
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<ENDPROVIDER
terraform {
  required_providers {
    sbercloud = {
      source = "sbercloud-terraform/sbercloud"
    }
  }
}

provider "sbercloud" {
  auth_url     = "https://iam.example-cloud.invalid/v3"
  region       = "ru-example-1"
  project_name = var.project_name
  access_key   = "${local.access_key}"
  secret_key   = "${local.secret_key}"
  security_token = "${local.security_token}"
}
ENDPROVIDER
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = "tfstate-project-a-example"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "ru-example-1"
    endpoints = { s3 = "https://obs.example-cloud.invalid" }
    access_key = get_env("TFSTATE_ACCESS_KEY", "")
    secret_key = get_env("TFSTATE_SECRET_KEY", "")
    use_lockfile = true
    skip_credentials_validation  = true
    skip_region_validation       = true
    skip_metadata_api_check      = true
    skip_requesting_account_id   = true
    skip_s3_checksum             = true
    disable_aws_client_checksums = true
  }
}

inputs = {
  project_name = local.project_name
}
