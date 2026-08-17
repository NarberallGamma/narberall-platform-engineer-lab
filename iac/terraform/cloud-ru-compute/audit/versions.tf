terraform {
  required_version = ">= 1.11.0"

  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "1.12.18"
    }
  }
}
