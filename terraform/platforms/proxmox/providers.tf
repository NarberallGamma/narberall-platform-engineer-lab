variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key injected into guests (set via tfvars / CI, never commit private keys)"
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_parallel         = 2
}

variable "proxmox_api_url" {
  type    = string
  default = "https://pve.example.com:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type    = string
  default = "root@pam!terraform"
}
