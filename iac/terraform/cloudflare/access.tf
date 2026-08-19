# Zero Trust Access in front of ops UIs. Account-level; zone is example.com.

resource "cloudflare_access_application" "grafana" {
  account_id                = var.cloudflare_account_id
  name                      = "grafana-example"
  domain                    = "grafana.example.com"
  type                      = "self_hosted"
  session_duration          = "8h"
  auto_redirect_to_identity = false
}

resource "cloudflare_access_policy" "grafana_ops" {
  application_id = cloudflare_access_application.grafana.id
  account_id     = var.cloudflare_account_id
  name           = "ops-email"
  precedence     = 1
  decision       = "allow"

  include {
    email_domain = ["example.com"]
  }
}

resource "cloudflare_access_application" "gitlab" {
  account_id       = var.cloudflare_account_id
  name             = "gitlab-example"
  domain           = "gitlab.example.com"
  type             = "self_hosted"
  session_duration = "12h"
}

resource "cloudflare_access_policy" "gitlab_ops" {
  application_id = cloudflare_access_application.gitlab.id
  account_id     = var.cloudflare_account_id
  name           = "ops-email"
  precedence     = 1
  decision       = "allow"

  include {
    email_domain = ["example.com"]
  }
}
