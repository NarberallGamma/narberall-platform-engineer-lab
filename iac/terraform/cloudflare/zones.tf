# Several zones in one root (ccTLD / product / academy), not a single tutorial zone.

resource "cloudflare_zone" "primary" {
  account_id = var.cloudflare_account_id
  zone       = "example.com"
  plan       = "pro"
}

resource "cloudflare_zone" "shop" {
  account_id = var.cloudflare_account_id
  zone       = "shop.example.org"
  plan       = "pro"
}

resource "cloudflare_zone" "academy" {
  account_id = var.cloudflare_account_id
  zone       = "academy.example.net"
  plan       = "pro"
}
