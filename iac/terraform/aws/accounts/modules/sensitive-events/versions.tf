terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws.staging_eu_central_1,
        aws.prod_ap_southeast_1,
      ]
    }
  }
}
