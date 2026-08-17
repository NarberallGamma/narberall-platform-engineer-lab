variable "volume_types" {
  description = "EVS / RDS volume type names"
  type        = map(string)
  default = {
    sas      = "SAS"
    essd     = "ESSD"
    cloudssd = "CLOUDSSD"
  }
}
