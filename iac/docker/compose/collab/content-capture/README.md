# Content Capture OCR (host Compose)

**Business first:** OCR is a **nine-service vendor stack on host-net**, not a sidecar in the LLM chart. Hub: [`../../../`](../../../). Collab index: [`../`](../). Ansible host map: [`../../../../ansible/reference/ansible-llm-collab/`](../../../../ansible/reference/ansible-llm-collab/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used Content Capture **14.12.0** (`dockerregistry.content.ai`) with Postgres 16, an appserver on `:8443`, processing server/station, and web stations. nginx sits in front with path rewrite to AppServer and stations. Secrets stay in `.env`.

```text
content-capture/
  docker-compose.yml                 # 9 services, host-net, healthcheck
  .env.example                       # PG, machine-key, Kestrel, basic-auth
  nginx/conf.d/cc.example.com.conf   # TLS vhost, prefix strip
```

```bash
# from this directory, after .env, Certificate/, file_storage/, and logs exist:
cp .env.example .env
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Vendor pins | Product registry, not a generic .NET image |
| `network_mode: host` | Stations talk to appserver on host ports |
| Postgres healthcheck | Appserver waits `service_healthy` |
| nginx `server{}` | One `proxy_pass` to `:8443`. A second pass to `:443` 404s (comment in the vhost) |

## Honest gap

Vendor images, Kestrel PEM, machine keys, and `./postgres_data` stay out of git. Main `nginx.conf` was not in the snapshot (only the `server{}`). Samba bind is commented as `/path/to/samba`.

**Keywords:** Content Capture, OCR, PostgreSQL, nginx, host network
