variable "name" { type = string }
variable "ami" { type = string }
variable "instance_type" { type = string }
variable "key_name" { type = string }
variable "subnet_id" { type = string }
variable "security_group_ids" { type = list(string) }
variable "root_volume_type" { type = string, default = "gp2" }
variable "root_volume_size" { type = number, default = 40 }
variable "storage_volume_type" { type = string, default = "gp2" }
variable "storage_volume_size" { type = number, default = 100 }
