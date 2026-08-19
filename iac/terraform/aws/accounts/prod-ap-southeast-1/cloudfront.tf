resource "aws_cloudfront_distribution" "prod_web" {
  aliases             = ["www.example.com"]
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "prod web"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name = "ingress-b.ap-southeast-1.elb.amazonaws.com"
    origin_id   = "prod-alb"

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
    target_origin_id       = "prod-alb"
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
    cloudfront_default_certificate = true
  }
}
