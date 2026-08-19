resource "cloudflare_record" "primary_mx_a" {
  zone_id  = cloudflare_zone.primary.id
  name     = "@"
  type     = "MX"
  content  = "mx1.example.com"
  priority = 10
  ttl      = 3600
  proxied  = false
}

resource "cloudflare_record" "primary_mx_b" {
  zone_id  = cloudflare_zone.primary.id
  name     = "@"
  type     = "MX"
  content  = "mx2.example.com"
  priority = 20
  ttl      = 3600
  proxied  = false
}

resource "cloudflare_record" "primary_spf" {
  zone_id = cloudflare_zone.primary.id
  name    = "@"
  type    = "TXT"
  content = "v=spf1 include:_spf.example.com -all"
  ttl     = 3600
  proxied = false
}

resource "cloudflare_record" "primary_dmarc" {
  zone_id = cloudflare_zone.primary.id
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
  ttl     = 3600
  proxied = false
}

resource "cloudflare_record" "primary_dkim" {
  zone_id = cloudflare_zone.primary.id
  name    = "selector1._domainkey"
  type    = "CNAME"
  content = "selector1-example-com._domainkey.example.net"
  ttl     = 3600
  proxied = false
}

resource "cloudflare_record" "primary_caa" {
  zone_id = cloudflare_zone.primary.id
  name    = "@"
  type    = "CAA"
  data {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }
  ttl     = 3600
  proxied = false
}
