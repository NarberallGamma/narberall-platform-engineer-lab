provider "aws" {
  region  = "eu-central-1"
  profile = "legacy-aws-example"

  default_tags {
    tags = {
      Terraform = "true"
      Project   = "project-legacy-a"
    }
  }
}
