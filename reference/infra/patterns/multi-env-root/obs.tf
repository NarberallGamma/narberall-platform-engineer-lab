resource "sbercloud_obs_bucket" "prod_app_assets" {
  bucket        = "project-a-prod-app-assets"
  storage_class = "STANDARD"

  lifecycle {
    ignore_changes = [acl, force_destroy]
  }

  tags = {
    env     = "prod"
    project = "project-a"
  }
}

resource "sbercloud_obs_bucket" "preprod_app_assets" {
  bucket        = "project-a-preprod-app-assets"
  storage_class = "STANDARD"

  lifecycle {
    ignore_changes = [acl, force_destroy]
  }

  tags = {
    env     = "preprod"
    project = "project-a"
  }
}

resource "sbercloud_obs_bucket" "shared_artifacts" {
  bucket        = "project-a-shared-artifacts"
  storage_class = "STANDARD"

  lifecycle {
    ignore_changes = [acl, force_destroy]
  }
}
