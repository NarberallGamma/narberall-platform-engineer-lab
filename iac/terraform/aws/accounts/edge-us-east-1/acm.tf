resource "aws_acm_certificate" "staging_wildcard" {
  domain_name               = "*.staging.k8s.example.com"
  subject_alternative_names = ["staging.k8s.example.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "prod_wildcard" {
  domain_name               = "*.k8s.example.com"
  subject_alternative_names = ["k8s.example.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

output "staging_acm_arn" {
  value = aws_acm_certificate.staging_wildcard.arn
}

output "prod_acm_arn" {
  value = aws_acm_certificate.prod_wildcard.arn
}
