# Allow-list only. Office / VPN use RFC 5737 docs addresses.
# Cloudflare published ranges are public knowledge and stay as CDN edge.

resource "aws_wafv2_ip_set" "allow" {
  name               = "edge-allow"
  description        = "Office, VPN, and CDN edge"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses = [
    "203.0.113.10/32",
    "198.51.100.20/32",
    "203.0.113.50/32",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "108.162.192.0/18",
    "131.0.72.0/22",
    "141.101.64.0/18",
    "162.158.0.0/15",
    "172.64.0.0/13",
    "173.245.48.0/20",
    "188.114.96.0/20",
    "190.93.240.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
  ]
}

resource "aws_wafv2_web_acl" "edge" {
  name  = "edge-acl"
  scope = "CLOUDFRONT"

  default_action {
    block {}
  }

  rule {
    name     = "allow-known"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.allow.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow-known"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "edge-acl"
    sampled_requests_enabled   = true
  }
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.edge.arn
}
