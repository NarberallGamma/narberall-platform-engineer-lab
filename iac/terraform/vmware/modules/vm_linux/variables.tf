variable "org_name" {
  type = string
}

variable "org_vdc" {
  type = string
}

variable "vapp_name" {
  type = string
}

variable "vm_name" {
  type = string
}

variable "computer_name" {
  type        = string
  description = "At most 15 characters, no underscore (VCD limit)."
}

variable "cpus" {
  type        = number
  default     = 8
  description = "Total vCPU."
}

variable "cpu_cores" {
  type        = number
  default     = 8
  description = "Cores per socket. Sockets = cpus / cpu_cores."
}

variable "memory_mb" {
  type    = number
  default = 32768
}

variable "os_type" {
  type    = string
  default = "ubuntu64Guest"
}

variable "hardware_version" {
  type    = string
  default = "vmx-19"
}

variable "firmware" {
  type    = string
  default = "efi"
}

variable "efi_secure_boot" {
  type    = bool
  default = false
}

variable "power_on" {
  type    = bool
  default = true
}

variable "storage_policy" {
  type    = string
  default = "gold"
}

variable "disk_iops" {
  type = object({
    os   = number
    data = number
    wal  = number
  })
}

variable "disks" {
  type = object({
    os_gb   = number
    data_gb = number
    wal_gb  = number
  })
}

variable "network_name" {
  type = string
}

variable "ip_allocation_mode" {
  type    = string
  default = "DHCP"
}

variable "ip_address" {
  type    = string
  default = null
}

variable "boot_image_id" {
  type    = string
  default = null
}

variable "vapp_template_id" {
  type        = string
  default     = null
  description = "vApp template ID (Ubuntu-24.04). If set, empty+ISO is not used."
}

variable "guest_customization_enabled" {
  type    = bool
  default = false
}

variable "admin_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "root password for VCD Guest OS Customization."
}

variable "guest_initscript" {
  type        = string
  default     = ""
  sensitive   = true
  description = "VCD customization.initscript. Hosted VCD often caps at 1500 characters."
}

variable "extra_disk_delay" {
  type        = string
  default     = "60s"
  description = "Wait after VM create before extra disks (hashicorp/time: 60s = 60 seconds). allow_vm_reboot otherwise cuts Guest Customization."
}
