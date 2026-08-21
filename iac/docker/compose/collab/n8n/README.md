# n8n + Postgres (host Compose)

**Business first:** forms and webhooks are a **pinned n8n plus its own Postgres**, not a cluster operator. Hub: [`../../../`](../../../). Collab index: [`../`](../). Ansible workflow JSON: [`../../../../ansible/reference/ansible-llm-collab/`](../../../../ansible/reference/ansible-llm-collab/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used `n8nio/n8n:1.121.0` with `postgres:16` on an external `n8n_default` net. Basic-auth and `N8N_HOST` come from `.env`. Data is `./data` into `/home/node/.n8n` (image home, not a host username).

```text
n8n/
  docker-compose.yml    # n8n :5678 + Postgres :5432
  .env.example          # DB, basic-auth, host, PUID/PGID
```

```bash
# from this directory, after .env and the external network exist:
cp .env.example .env
docker network create n8n_default
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Own Postgres | Workflow DB is not borrowed from Nextcloud |
| `N8N_PROTOCOL=https` + webhook URL | Reverse-proxy contract |
| `user: PUID:PGID` | Host uid map for `./data` |

## Honest gap

The Postgres service uses `- POSTGRES_USER:${VAR}` (colon, not `=`). That is the live YAML; `compose up` may fail until those three lines use `=`. Ansible `n8n_workflows` syncs JSON via REST. It does not replace this compose.

**Keywords:** n8n, Postgres, basic-auth, webhook
