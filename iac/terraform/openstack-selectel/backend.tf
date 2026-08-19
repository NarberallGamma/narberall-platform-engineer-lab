terraform {
  backend "s3" {
    bucket                      = "tfstate-example"
    key                         = "selectel/ru-1/terraform.tfstate"
    region                      = "ru-1"
    endpoint                    = "https://s3.ru-1.storage.selcloud.ru"
    profile                     = "selectel-example"
    skip_region_validation      = true
    skip_credentials_validation = true
    force_path_style            = true
  }
}
