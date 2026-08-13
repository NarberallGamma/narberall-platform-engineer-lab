# Terraform / provider version pins. Auth and backend stay in provider.tf (local copy).

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vkcs = {
      source  = "vk-cs/vkcs"
      version = "~> 0.17.0"
    }
  }
}
