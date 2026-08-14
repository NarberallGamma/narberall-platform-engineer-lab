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
