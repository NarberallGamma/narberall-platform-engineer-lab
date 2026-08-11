provider "aws" {
  region  = "eu-central-1"
  profile = "aws-example"

  default_tags {
    tags = {
      Terraform = "true"
      Project   = "project-a"
    }
  }
}
