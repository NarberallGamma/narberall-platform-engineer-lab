# Platform: Cloudflare (DNS as code)

Several zones in one root (apex + shop + academy), not a single tutorial record pair.

| File | Resources |
|------|-----------|
| `zones.tf` | 3 zones (example.com, shop.example.org, academy.example.net) |
| `records_apex.tf` | Apex A + www CNAME per zone |
| `records_app.tf` | app/api/status/grafana A, gitlab/vault/argocd CNAME, shop/academy hosts |
| `records_mail.tf` | MX, SPF, DKIM, DMARC, CAA |
| `page_rules.tf` | zone settings (strict TLS) + cache/bypass page rules |
| `access.tf` | Zero Trust Access apps (grafana, gitlab) + email-domain policies |

Documentation IPs only (`203.0.113.0/24`, `198.51.100.0/24`). Token via `TF_VAR_cloudflare_api_token`.

Experience: [`../../cloud/cloudflare.md`](../../cloud/cloudflare.md)  
Map: [`../RESOURCES.md`](../RESOURCES.md)
