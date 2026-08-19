# Terragrunt root for a greenfield vkcs unit (sec-monitor).
# State is S3-compatible object storage (VK Hotbox-class), not AWS.
# Bucket name and project_id stay example-only in this lab.

locals {
  env = {
    project_id = "00000000000000000000000000000000"
    region     = "RegionOne"
    auth_url   = "https://infra.example.com:5000/v3/"
  }
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket = "tfstate-example"
    key    = "sec-monitor/${path_relative_to_include()}/terraform.tfstate"
    region = "ru-msk-1"
    endpoints = {
      s3 = "https://s3.example.com"
    }
    use_lockfile                 = true
    skip_credentials_validation  = true
    skip_region_validation       = true
    skip_requesting_account_id   = true
    skip_metadata_api_check      = true
    skip_s3_checksum             = true
    disable_aws_client_checksums = true
    skip_bucket_versioning             = true
    skip_bucket_ssencryption           = true
    skip_bucket_root_access            = true
    skip_bucket_enforced_tls           = true
    skip_bucket_public_access_blocking = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
variable "vkcs_username" {
  type    = string
  default = ""
}

variable "vkcs_password" {
  type      = string
  default   = ""
  sensitive = true
}

provider "vkcs" {
  username   = var.vkcs_username != "" ? var.vkcs_username : null
  password   = var.vkcs_password != "" ? var.vkcs_password : null
  project_id = "${local.env.project_id}"
  region     = "${local.env.region}"
  auth_url   = "${local.env.auth_url}"
}
EOF
}
