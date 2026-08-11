terraform {
  required_version = ">= 0.14"
  required_providers {
    selectel = {
      source = "selectel/selectel"
    }
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}
