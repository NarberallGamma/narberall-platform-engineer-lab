variable "region" {
    type = string
    description = "The region in which to obtain the V2 networking client. A networking client is needed to create a port. If omitted, the region argument of the provider is used. Changing this creates a new security group."
    default = null
}

variable "name" {
    type = string
    description = "A unique name for the security group."
}

variable "description" {
    type = string
    description = "Description of the security group."
    default = null
}

variable "enterprise_project_id" {
    type = string
    description = "Specifies the enterprise project id of the security group. Changing this creates a new security group."
    default = null
}

variable "delete_default_rules" {
    type = bool
    description = "Whether or not to delete the default egress security rules. This is false by default. See the below note for more information."
    default = true
}

# Cloud project
variable "project_name" {
        description = "Cloud project name like example: project-a-dev"
}
