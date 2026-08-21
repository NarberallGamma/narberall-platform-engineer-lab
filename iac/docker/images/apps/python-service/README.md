# FastAPI worker (python-service)

**Business first:** the DEV stand had a **FastAPI worker on :8401** next to the in-cluster LLM API, not a second helmfile. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Chart half: [`../../../../helm/apps/helmfile-dev/`](../../../../helm/apps/helmfile-dev/). Helmfile CI image: [`../../ci/helmfile/`](../../ci/helmfile/).

I used this image when product charts lived in two repos and CI applied each helmfile on its own. The published SAMPLE keeps `llm-api` plus `feed-api` / `feed-rss`. The watcher chart stayed out (thin Deployment + PVC + ConfigMap). This folder is the FastAPI image that stand used next to those helmfiles. App source is not in git.

```text
python-service/
  Dockerfile         # python:3.12.3-slim, COPY . ., pip, :8401, python __main__.py
  requirements.txt   # FastAPI, uvicorn, LangChain, aiogram
  .env.example       # LLM base URL + Telegram placeholders
```

```bash
# from this directory, after __main__.py and the package tree are the context:
docker build -t example.registry/apps/python-service:local .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Slim 3.12 + `COPY . .` | One file, whole tree. Same habit as the omitted watcher chart |
| Port 8401 | Distinct from feed-api on :8400 |
| `.env.example` | OpenAI-compatible base URL points at `llm-api.example.com:11434`. Tokens stay `CHANGE_ME` |
| Helmfile stand | Image half of [`../../../../helm/apps/helmfile-dev/`](../../../../helm/apps/helmfile-dev/). CI image that applied the stands is [`../../ci/helmfile/`](../../ci/helmfile/) |

## Honest gap

`__main__.py` and the package tree are not in this folder. `COPY . .` expects that tree. A rebuild from this directory alone fails. `requirements.txt` is enough to see FastAPI + LangChain + Telegram, not enough to run the worker.

The live watcher chart is not in `helmfile-dev` (SKIP: thin clone, live tokens in ConfigMap). This image is still the worker that stand used.

**Keywords:** FastAPI, Python 3.12, LangChain, uvicorn, helmfile-dev, :8401
