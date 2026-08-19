resource "cloudflare_record" "primary_apex" {
  zone_id = cloudflare_zone.primary.id
  name    = "@"
  type    = "A"
  content = "203.0.113.10"
  ttl     = 300
  proxied = true
}

resource "cloudflare_record" "primary_www" {
  zone_id = cloudflare_zone.primary.id
  name    = "www"
  type    = "CNAME"
  content = "example.com"
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "shop_apex" {
  zone_id = cloudflare_zone.shop.id
  name    = "@"
  type    = "A"
  content = "203.0.113.20"
  ttl     = 300
  proxied = true
}

resource "cloudflare_record" "shop_www" {
  zone_id = cloudflare_zone.shop.id
  name    = "www"
  type    = "CNAME"
  content = "shop.example.org"
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "academy_apex" {
  zone_id = cloudflare_zone.academy.id
  name    = "@"
  type    = "A"
  content = "198.51.100.10"
  ttl     = 300
  proxied = true
}

resource "cloudflare_record" "academy_www" {
  zone_id = cloudflare_zone.academy.id
  name    = "www"
  type    = "CNAME"
  content = "academy.example.net"
  ttl     = 1
  proxied = true
}
