terraform {
  backend "s3" {
    bucket  = "tfstate-legacy-example"
    key     = "aws/infra/terraform.tfstate"
    region  = "eu-central-1"
    profile = "legacy-aws-example"
  }
}
