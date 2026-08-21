# Feed Telegram bridge (ships-bridge)

**Business first:** the Telegram reader is a **separate worker image**, not a flag on the HTTP API. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Chart half: [`../../../../helm/apps/helmfile-dev/`](../../../../helm/apps/helmfile-dev/). API sibling: [`../ships-api/`](../ships-api/). Helmfile CI image: [`../../ci/helmfile/`](../../ci/helmfile/).

I used this image next to `feed-api`. The published helmfile SAMPLE keeps `BRIDGE_ENABLED=0` on the API and does not ship the bridge chart (stand values held a bot token). This folder is the worker image that chart would have run. Skills are not in git.

```text
ships-bridge/
  Dockerfile    # python:3.12-slim, aiogram + requests, COPY bridge.py + scripts/, python3 bridge.py
```

```bash
# from this directory, after skills/ships-api/bridge.py and scripts/ are the context:
docker build -t example.registry/apps/feed-bridge:local .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Own process | Live estate did not embed the reader in the API pod |
| `COPY` two paths | `bridge.py` plus `scripts/` from the same skills tree the API image copies |
| `/app/memory` | Same PVC habit as [`../ships-api/`](../ships-api/) |
| No `EXPOSE` | Worker, not a Service |

## Honest gap

`skills/ships-api/bridge.py` and `skills/ships-api/scripts/` are not in this folder. A rebuild from this directory alone fails.

The bridge Helm chart is not in `helmfile-dev` (SKIP: same helpers as `feed-api`, live token in values). The stand and the API/RSS charts are still the chart half of this image.

**Keywords:** aiogram, Telegram bridge, feed-api, helmfile-dev, worker
