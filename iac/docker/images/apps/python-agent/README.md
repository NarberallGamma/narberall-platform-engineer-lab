# Python FastAPI agent (Gradle-stub CI)

**Business first:** the shop Python agent is a **FastAPI image that still accepts the shared Gradle CI args**, so one pipeline shape covers Java and this service. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Combined Java sibling: [`../java-gradle/`](../java-gradle/).

I used this Dockerfile for the FastAPI + Alembic agent. `python:3.13-slim` installs the pin list, then `alembic upgrade head` and `uvicorn` on 8080. `GRADLE_PARAMS` is a no-op stub so the shared wrapper can still invoke the image. App source and the Gradle metadata files are not in git.

```text
python-agent/
  Dockerfile           # python:3.13-slim, pip pins, USER 1000, alembic + uvicorn
  requirements.txt     # FastAPI / Alembic / LangGraph pins (public packages)
```

```bash
# from this directory, after the FastAPI tree (main.py, alembic, build.gradle) is the context:
docker build -t example.registry/shop-app/python-agent:local \
  --build-arg VERSION=0.0.1 \
  --build-arg GRADLE_PARAMS='--no-daemon' \
  .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Gradle stub `RUN` | Shared CI args do not require a JVM in this image |
| `COPY build.gradle settings.gradle` | Wrapper metadata stays on the context |
| Alembic then uvicorn | Migrate on start, listen on 8080 (8000 is also exposed) |
| `USER 1000` | Non-root runtime |
| Pin file | Public deps including a vendor LLM SDK name (not an employer brand) |

## Honest gap

`main.py`, Alembic revisions, `build.gradle`, and `settings.gradle` are not in this folder. `COPY` lines expect that tree. A rebuild from this directory alone fails.

This is **not** a generic `python-service` image. A different Python app Dockerfile lives in a sibling folder when that slice is published.

**Keywords:** FastAPI, Alembic, uvicorn, Python 3.13, Gradle stub
