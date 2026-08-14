# Storage policy and IOPS ceiling (catalog). Disk sizes live in vm-*.tf.

variable "storage" {
  type = object({
    policy            = string
    iops_per_gb_max   = number
    maximum_disk_iops = number
  })
  description = "Fallback IOPS if data.vcd_storage_profile has empty iops_settings."
  default = {
    policy            = "gold"
    iops_per_gb_max   = 40
    maximum_disk_iops = 40000
  }
}
