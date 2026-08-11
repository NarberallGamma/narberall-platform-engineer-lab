terraform {
  required_version = ">= 1.5.0"
  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = ">= 1.12.0"
    }
  }

  backend "s3" {
    bucket                      = "tfstate-project-a-example"
    key                         = "multi-env/terraform.tfstate"
    region                      = "ru-example-1"
    endpoints                   = { s3 = "https://obs.example-cloud.invalid" }
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "sbercloud" {
  auth_url   = "https://iam.example-cloud.invalid/v3"
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}
