locals {
  primary_a = {
    app     = "203.0.113.10"
    api     = "203.0.113.11"
    status  = "203.0.113.12"
    grafana = "203.0.113.13"
  }
  primary_cname = {
    gitlab = "app.example.com"
    vault  = "app.example.com"
    argocd = "app.example.com"
    docs   = "app.example.com"
  }
}

resource "cloudflare_record" "primary_app_a" {
  for_each = local.primary_a

  zone_id = cloudflare_zone.primary.id
  name    = each.key
  type    = "A"
  content = each.value
  ttl     = 300
  proxied = true
}

resource "cloudflare_record" "primary_app_cname" {
  for_each = local.primary_cname

  zone_id = cloudflare_zone.primary.id
  name    = each.key
  type    = "CNAME"
  content = each.value
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "shop_checkout" {
  zone_id = cloudflare_zone.shop.id
  name    = "checkout"
  type    = "A"
  content = "203.0.113.21"
  ttl     = 300
  proxied = true
}

resource "cloudflare_record" "shop_cdn" {
  zone_id = cloudflare_zone.shop.id
  name    = "cdn"
  type    = "CNAME"
  content = "shop.example.org"
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "academy_lms" {
  zone_id = cloudflare_zone.academy.id
  name    = "lms"
  type    = "A"
  content = "198.51.100.11"
  ttl     = 300
  proxied = true
}

resource "cloudflare_record" "academy_static" {
  zone_id = cloudflare_zone.academy.id
  name    = "static"
  type    = "CNAME"
  content = "academy.example.net"
  ttl     = 1
  proxied = true
}
