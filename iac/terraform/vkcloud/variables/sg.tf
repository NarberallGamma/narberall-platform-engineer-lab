# Security group key -> SG UUID (fake IDs in this lab).

variable "sg_ids" {
  description = "SG key to security group UUID"
  type        = map(string)
  default = {
    default = "00000000-0000-4000-8000-000000000101"
    app     = "00000000-0000-4000-8000-000000000102"
    db      = "00000000-0000-4000-8000-000000000103"
  }
}
