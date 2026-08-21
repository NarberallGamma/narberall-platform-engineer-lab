# Jira Software (host Compose)

**Business first:** the tracker is a **pinned Atlassian image on a shared frontend net**, not a Helm chart. Hub: [`../../../`](../../../). Collab index: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used `atlassian/jira-software:9.15.2` behind TLS at `jira.example.com`. Tomcat sees HTTPS via `ATL_PROXY_*`. JVM `setenv.sh` and a host `cacerts` bind sit next to app data. The `frontend` network is external (shared with wiki / JSM).

```text
jira/
  docker-compose.yml    # :8082→8080, dns 10.10.1.9, json-file 100m×5
```

```bash
# from this directory, after Volumes/setenv.sh, cacerts, and app_data exist
# and the external network frontend is created:
docker network create frontend
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `ATL_PROXY_NAME` / `PORT` / `SCHEME` | Reverse proxy contract, not a published 8080 to the internet |
| Host `cacerts` | Extra CAs for LDAPS / SMTP without rebuilding the image |
| External `frontend` | One net for the Atlassian trio |

## Honest gap

`./Volumes/` (setenv, agent, app_data, cacerts) is not in git. A `compose up` from this folder alone starts an empty Jira that cannot persist or trust extra CAs.

**Keywords:** Jira Software, Atlassian, ATL_PROXY, cacerts, json-file
