resource "cloudflare_zone_settings_override" "primary" {
  zone_id = cloudflare_zone.primary.id
  settings {
    ssl                      = "strict"
    always_use_https         = "on"
    min_tls_version          = "1.2"
    automatic_https_rewrites = "on"
    brotli                   = "on"
    security_level           = "medium"
  }
}

resource "cloudflare_page_rule" "primary_static" {
  zone_id  = cloudflare_zone.primary.id
  target   = "example.com/static/*"
  priority = 1
  status   = "active"
  actions {
    cache_level = "cache_everything"
    edge_cache_ttl = 86400
  }
}

resource "cloudflare_page_rule" "primary_admin" {
  zone_id  = cloudflare_zone.primary.id
  target   = "example.com/admin/*"
  priority = 2
  status   = "active"
  actions {
    cache_level = "bypass"
    security_level = "high"
  }
}

resource "cloudflare_page_rule" "shop_assets" {
  zone_id  = cloudflare_zone.shop.id
  target   = "shop.example.org/assets/*"
  priority = 1
  status   = "active"
  actions {
    cache_level = "cache_everything"
  }
}
