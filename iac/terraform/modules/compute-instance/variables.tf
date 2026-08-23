variable "instances" {
  description = "Map of per-instance configurations. The key is the name suffix (e.g. \"01\")."
  type = map(object({
    availability_zone  = optional(string)
    networks = list(object({
      uuid              = string
      fixed_ip          = optional(string, "")
      ipv6_enable       = optional(bool, false)
      source_dest_check = optional(bool, true)
      access_network    = optional(bool, false)
    }))
    security_group_ids = optional(list(string))
    flavor_id          = optional(string)
    image_id           = optional(string)
    image_name         = optional(string)
    system_disk_type   = optional(string)
    system_disk_size   = optional(number)
    data_disks = optional(list(object({
      type        = string
      size        = number
      snapshot_id = optional(string)
      kms_key_id  = optional(string)
    })))
    tags = optional(map(string))
  }))
  default = null
}

# --- Shared parameters (used when instances is unset, or as fallback) ---
variable "instance_count" {
  description = "Number of instances (when instances is unset)"
  type        = number
  default     = 1
}

variable "instance_name" {
  description = "Base instance name"
  type        = string
}

variable "availability_zones" {
  description = "Availability zone list (shared fallback). One element applies to all; length = instance_count assigns one zone per instance."
  type        = list(string)
  default     = []
}

variable "networks" {
  description = "Shared network list (without fixed_ip when used without instances)."
  type = list(object({
    uuid              = string
    fixed_ip          = optional(string, "")
    ipv6_enable       = optional(bool, false)
    source_dest_check = optional(bool, true)
    access_network    = optional(bool, false)
  }))
  default = []
}

variable "flavor_id" {
  description = "Flavor ID (shared)"
  type        = string
}

variable "image_id" {
  description = "Image ID (shared, when image_name is unset)"
  type        = string
  default     = null
}

variable "image_name" {
  description = "Image name (shared, takes precedence over image_id)"
  type        = string
  default     = ""
}

variable "security_group_ids" {
  description = "Shared security group list (unless overridden in instances)"
  type        = list(string)
  default     = []
}

variable "system_disk_type" {
  type    = string
  default = "GPSSD"
}
variable "system_disk_size" {
  type    = number
  default = 40
}
variable "data_disks" {
  type = list(object({
    type        = string
    size        = number
    snapshot_id = optional(string)
    kms_key_id  = optional(string)
  }))
  default = []
}

variable "anti_affinity_enabled" {
  type    = bool
  default = false
}
variable "scheduler_hints" {
  type = object({
    group   = optional(string)
    tenancy = optional(string)
    deh_id  = optional(string)
  })
  default = null
}

variable "eip_type" { 
  type = string
  default = null 
}

variable "bandwidth" {
  type = object({
    share_type  = string
    size        = number
    id          = optional(string)
    charge_mode = optional(string)
  })
  default = null
}
variable "eip_id" {
  description = "Existing EIP ID"
  type        = string
  default     = null
}

variable "key_pair" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

variable "admin_pass" {
  description = "Administrator password (incompatible with cloud-init)"
  type        = string
  default     = null
  sensitive   = true
}

variable "private_key" {
  description = "Private key used to replace or detach key_pair"
  type        = string
  default     = null
  sensitive   = true
}

variable "user_data" {
  description = "Cloud-init user data"
  type        = string
  default     = null
}

variable "tags" {
  description = "Instance tags"
  type        = map(string)
  default     = {}
}

variable "description" {
  description = "Instance description"
  type        = string
  default     = ""
}

variable "stop_before_destroy" {
  description = "Whether to stop the instance before destroy"
  type        = bool
  default     = true
}

variable "delete_disks_on_termination" {
  description = "Whether to delete disks when the instance is terminated"
  type        = bool
  default     = false
}

variable "delete_eip_on_termination" {
  description = "Whether to delete the EIP when the instance is terminated"
  type        = bool
  default     = true
}

variable "enterprise_project_id" {
  description = "Enterprise project ID"
  type        = string
  default     = null
}

variable "user_id" {
  description = "User ID (required when key_pair is used with pre-paid)"
  type        = string
  default     = null
}

variable "agency_name" {
  description = "IAM agency name"
  type        = string
  default     = null
}

variable "agent_list" {
  description = "Comma-separated agent list"
  type        = string
  default     = null
}

variable "power_action" {
  description = "Power action: ON, OFF, REBOOT, FORCE-OFF, FORCE-REBOOT"
  type        = string
  default     = null
}

variable "charging_mode" {
  description = "Charging mode: postPaid or prePaid"
  type        = string
  default     = "postPaid"
}

variable "period_unit" {
  description = "Period unit for prePaid"
  type        = string
  default     = null
}

variable "period" {
  description = "Period for prePaid"
  type        = number
  default     = null
}

variable "auto_renew" {
  description = "Auto-renewal for prePaid"
  type        = string
  default     = null
}

variable "region" {
  description = "Region (when not set at the provider level)"
  type        = string
  default     = null
}
