# Jira Service Management (host Compose)

**Business first:** JSM is a **third Atlassian pin**, not the Software image with a plugin toggle. Hub: [`../../../`](../../../). Collab index: [`../`](../). Siblings: [`../jira/`](../jira/), [`../wiki/`](../wiki/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used `atlassian/jira-servicemanagement:5.11` on the same external `frontend` net. Port is `:8083` so it does not collide with Software `:8082`. Same `ATL_PROXY_*` and host `cacerts` habit.

```text
servicedesk/
  docker-compose.yml    # :8083→8080, dns 10.10.1.9
```

```bash
# from this directory, after Volumes/ and the frontend network exist:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Own image | `jira-servicemanagement:5.11`, not Software 9.15.2 |
| Own host port | `:8083` next to Jira `:8082` and Confluence `:8090` |
| Same proxy contract | `servicedesk.example.com` + HTTPS scheme |

## Honest gap

`./Volumes/` is not in git. This is not the Ansible JSM host map; that inventory lives under [`../../../../ansible/reference/ansible-llm-collab/`](../../../../ansible/reference/ansible-llm-collab/).

**Keywords:** Jira Service Management, Atlassian, ATL_PROXY
