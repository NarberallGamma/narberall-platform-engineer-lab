terraform {
  backend "s3" {
    bucket                      = "tfstate-legacy-example"
    key                         = "selectel/ru-1/terraform.tfstate"
    region                      = "ru-1"
    endpoint                    = "https://s3.example-selectel.invalid"
    profile                     = "legacy-selectel-example"
    skip_region_validation      = true
    skip_credentials_validation = true
    force_path_style            = true
  }
}
