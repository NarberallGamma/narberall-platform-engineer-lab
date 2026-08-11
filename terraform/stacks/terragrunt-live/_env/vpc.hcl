locals {
  source_base_url = "${dirname(find_in_parent_folders("root.hcl"))}/../../modules/vpc"
}
