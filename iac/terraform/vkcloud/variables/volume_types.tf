# Volume type key -> volume_type name (public catalog names).

variable "volume_types" {
  description = "Volume type key to type name"
  type        = map(string)
  default = {
    ceph_ssd     = "ceph-ssd"
    high_iops    = "high-iops"
    high_iops_ha = "high-iops-ha"
  }
}
