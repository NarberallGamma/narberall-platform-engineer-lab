# Collab host Compose

**Business first:** Jira, wiki, JSM, Nextcloud, n8n, SMTP, the edge proxy, OCR, and a KRaft broker are **host `compose up`**, not a Helm umbrella. Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Ansible half (ACL, n8n workflows, Kafka role): [`../../../ansible/reference/ansible-llm-collab/`](../../../ansible/reference/ansible-llm-collab/). Case: [`../../../../case-studies/12-docker-images.md`](../../../../case-studies/12-docker-images.md).

I used these files on VMs next to the LLM/collab inventory. Each folder is one richest snapshot per product class. Twins (poorer Nextcloud hosts, extra edge-proxy profiles) stayed out. Secrets are `.env.example` / `CHANGE_ME` only.

```text
collab/
  jira/              # Jira Software 9.15.2, external frontend net
  wiki/              # Confluence + healthcheck + JVM env
  servicedesk/       # Jira Service Management 5.11
  nextcloud/         # fpm 31.0.6 + nginx + clamav + cron + redis
  n8n/               # n8n 1.121.0 + Postgres 16
  postfix/           # boky/postfix, DKIM/TLS, public DNS
  edge-proxy/        # nginx 1.27.4, host-net, custom conf + logs
  content-capture/   # 9-service OCR 14.12.0 + nginx vhost
  kafka-broker/      # Kafka 4.0.0 KRaft + Vault cert pull + docker.sock cron
```

```bash
# from a kit directory, after local volumes / certs / .env exist:
docker compose up -d
```

## What hiring should see

| Slice | Why it is here |
|-------|----------------|
| Atlassian trio | Same `frontend` net, `ATL_PROXY_*`, json-file 100m×5, host `cacerts` / `setenv.sh` |
| Nextcloud clients | Clamav socket + fpm + nginx bind `10.10.1.11:443` + cron + redis. Named bind volumes |
| n8n + Postgres | Basic-auth + webhook host. Live YAML typo on PG env kept |
| Postfix | Public resolvers `8.8.8.8` / `8.8.4.4` so outbound mail is not stuck on estate DNS |
| Edge nginx | `network_mode: host`, 50m×1 logs, conf + certs + logs binds |
| Content Capture | Vendor registry pins, host-net, healthcheck on Postgres, path-rewrite nginx |
| Kafka KRaft | Four listeners, PEM, SCRAM, Vault sidecar, weekly cert-mtime restart via docker.sock |

## Honest gaps

- App data, `cacerts`, `setenv.sh`, PEM, Vault tokens, and valued `.env` stay out of git
- n8n Postgres uses `- POSTGRES_USER:${VAR}` (colon, not `=`). That is the live file
- Kafka `min.insync.replicas=2` with `default.replication.factor=1` is the captured shape
- This folder is not the Ansible Nextcloud ACL / n8n JSON / Kafka `.j2` roles

**Keywords:** Compose, Jira, Confluence, JSM, Nextcloud, n8n, Postfix, nginx, Content Capture, Kafka, KRaft, Vault
