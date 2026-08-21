# Feed HTTP API (ships-api)

**Business first:** the feed stand is an **HTTP API on :8400** plus CronJobs, not one Argo Application. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Chart half: [`../../../../helm/apps/helmfile-dev/`](../../../../helm/apps/helmfile-dev/) (`feed-api`). Bridge worker: [`../ships-bridge/`](../ships-bridge/). Helmfile CI image: [`../../ci/helmfile/`](../../ci/helmfile/).

I used this image with the local `feed-api` chart (`example.registry/apps/feed-api`, ClusterIP :8400, `/health`, memory PVC). The chart injects `BRIDGE_ENABLED=0` because the live estate ran the Telegram reader as a separate pod ([`../ships-bridge/`](../ships-bridge/)). Skills and agent trees are not in git.

```text
ships-api/
  Dockerfile    # python:3.12-slim, flask + aiogram + requests, COPY skills/ + agents, :8400
```

```bash
# from this directory, after skills/ and the agent trees are the context:
docker build -t example.registry/apps/feed-api:local .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `COPY skills/` + two agent dirs | Layout the CronJob chart and the bridge worker share |
| `mkdir /app/memory` | PVC mount in the `feed-api` chart |
| Port 8400 | Same port as [`../../../../helm/apps/helmfile-dev/charts/feed-api/`](../../../../helm/apps/helmfile-dev/charts/feed-api/) |
| pip in the image | No lockfile. Honest pin-by-name |

## Honest gap

`skills/`, `ships-monitor-agent/`, and `ships-dispatcher/` are not in this folder. `CMD` runs `skills/ships-api/server.py`. A rebuild from this directory alone fails.

The RSS CronJob chart is `feed-rss` in the same helmfile SAMPLE. That image stayed out (thin print `CMD`, poller not copied). Three generic `feed-rss` releases are enough to show the stampede-avoidance overlay.

**Keywords:** Flask, Python 3.12, feed-api, helmfile-dev, :8400, skills COPY
