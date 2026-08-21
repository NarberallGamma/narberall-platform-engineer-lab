# official Python image
FROM mirror.gcr.io/python:3.13-slim

ARG DOCKER_HOST="tcp://172.17.0.1:2375"
ARG VERSION
ARG GRADLE_PARAMS

ENV VERSION=$VERSION

# minimal deps for git and pip
RUN apt update && \
    apt install -y --no-install-recommends git gcc python3-dev && \
    rm -rf /var/lib/apt/lists/*

# Gradle metadata files kept so the shared CI gradle wrapper can still invoke the image
COPY build.gradle settings.gradle ./

# Gradle CLI is not installed; this is a no-op stub for the shared build args
RUN if [ -n "$GRADLE_PARAMS" ]; then \
      echo "Stubbing Gradle command with args: $GRADLE_PARAMS"; \
    else \
      echo "No GRADLE_PARAMS provided"; \
    fi

# Python deps
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000
EXPOSE 8080

USER 1000


# migrate then serve
ENTRYPOINT ["sh", "-c", "alembic upgrade head && uvicorn main:app --host 0.0.0.0 --port 8080"]
