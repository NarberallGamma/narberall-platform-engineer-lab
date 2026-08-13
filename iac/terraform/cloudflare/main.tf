variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_zone" "primary" {
  account_id = var.cloudflare_account_id
  zone       = "example.com"
}

variable "cloudflare_account_id" {
  type = string
}

resource "cloudflare_record" "app" {
  zone_id = cloudflare_zone.primary.id
  name    = "app"
  type    = "A"
  content = "203.0.113.10"
  ttl     = 300
  proxied = true
}

resource "cloudflare_record" "api" {
  zone_id = cloudflare_zone.primary.id
  name    = "api"
  type    = "CNAME"
  content = "app.example.com"
  ttl     = 300
  proxied = true
}
