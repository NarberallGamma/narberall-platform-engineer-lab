/*
variable "region" {
    type = string
    default = null
}

variable "direction" {
    type = string
}

variable "ethertype" {
    type = string
}

variable "description" {
    type = string
    default = null
}

variable "protocol" {
    type = string
    default = null
}

variable "ports" {
    type = string
    default = null
}

variable "remote_ip_prefix" {
    type = string
    default = null
}

#### skip some variables

variable "security_group_id" {
    type = string
}

variable "action" {
    type = string
    default = null
}

variable "priority" {
    type = number
    default = 1
}
*/

variable "security_group_id" {
  description = "ID of the security group"
  type        = string
}

variable "rules" {
  description = "List of rules to apply to the security group"
  type = list(object({
    name              = string
    region            = string
    direction         = string
    ethertype         = string
    description       = string
    protocol          = string
    ports             = optional(string)
    port_range_min    = optional(string)
    port_range_max    = optional(string)
    remote_ip_prefix  = optional(string)
    remote_group_id   = optional(string)
    action            = string
    priority          = number
  }))
}

# IAM project
variable "project_name" {
        description = "IAM project name like SBC_REGION_NAME_PROJECT_NAME_FROM_WEBCONSOLE, e.g ru-moscow-1_my-awesome-project"
}
