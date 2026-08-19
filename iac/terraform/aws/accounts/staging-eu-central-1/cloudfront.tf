resource "aws_cloudfront_distribution" "staging_web" {
  aliases             = ["www.staging.example.com"]
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "staging web"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  web_acl_id          = var.waf_web_acl_arn

  origin {
    domain_name = "ingress-a.eu-central-1.elb.amazonaws.com"
    origin_id   = "staging-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "staging-alb"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_staging_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }
}
