terraform {
  backend "s3" {
    bucket  = "tfstate-example"
    key     = "aws/infra/terraform.tfstate"
    region  = "eu-central-1"
    profile = "aws-example"
  }
}
