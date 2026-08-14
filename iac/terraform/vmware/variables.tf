variable "vcd_url" {
  type        = string
  description = "VCD API, for example https://vcd.example.com/api"
}

variable "org_name" {
  type        = string
  description = "Org / tenant slug from the VCD URL"
}

variable "org_vdc" {
  type        = string
  description = "VDC display name"
}

variable "api_token_file" {
  type        = string
  default     = "token.json"
  description = "API token file path (not in git)"
}

variable "vcd_max_retry_timeout" {
  type    = number
  default = 1800
}

variable "vcd_allow_unverified_ssl" {
  type    = bool
  default = false
}

variable "create_vm" {
  type        = bool
  default     = false
  description = "false: data sources only. true: vApp + VM."
}

variable "guest_password_length" {
  type        = number
  default     = 30
  description = "Random password length for root, ubuntu, and each extra user."
}

variable "guest_password_override" {
  type        = string
  default     = ""
  sensitive   = true
  description = "If set, one password for all guest users (console without paste). Empty: random."
}

variable "guest_extra_users" {
  type        = list(string)
  default     = ["admin_platform"]
  description = "Extra logins: sudo NOPASSWD, same SSH pubkey. Do not list root or ubuntu."
}

variable "admin_ssh_public_key_file" {
  type        = string
  default     = ""
  description = "Pubkey file (several lines ok). Empty: files/ssh/authorized_keys"
}

variable "ubuntu_iso" {
  type = object({
    version      = string
    os_type      = string
    catalog_org  = string
    catalog_name = string
    media_name   = string
  })
  default = {
    version      = "24.04.3"
    os_type      = "ubuntu64Guest"
    catalog_org  = "shared-linux"
    catalog_name = "Linux"
    media_name   = "ubuntu-24.04.3-live-server-amd64.iso"
  }
}
