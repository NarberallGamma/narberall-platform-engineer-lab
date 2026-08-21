# Confluence (host Compose)

**Business first:** the wiki is a **separate image and JVM env**, not a flag on Jira. Hub: [`../../../`](../../../). Collab index: [`../`](../). Sibling: [`../jira/`](../jira/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used Confluence on the same external `frontend` net as Jira. Image tag and heap come from `.env`. Healthcheck hits `:8090`. Synchrony stays on `:8091`.

```text
wiki/
  docker-compose.yml    # Confluence, healthcheck, dns 10.10.1.9
  .env.example          # image tag, DATA_PATH, JVM min/max
```

```bash
# from this directory, after .env, cacerts, setenv.sh, and app_data exist:
cp .env.example .env
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Own compose | Wiki is not folded into the Jira file |
| `CONFLUENCE_IMAGE_TAG` | Pin lives in env, not a rebuild |
| Healthcheck | `curl -f http://localhost:8090/` with a 90s start period |

## Honest gap

`./Volumes/`, `./cacerts`, and a filled `.env` stay out of git. Image tag in the example is `CHANGE_ME`.

**Keywords:** Confluence, Atlassian, JVM, healthcheck
