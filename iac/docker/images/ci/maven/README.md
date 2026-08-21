# Maven + Docker CLI (CI)

**Business first:** one job image can compile a Java module, talk to a Docker daemon, and still have Node on PATH when a frontend step shares the worker.

The host is `node:26-alpine`. OpenJDK 17, Maven, and the Docker **client** are apk-added. `DOCKER_HOST=tcp://docker:2375` matches a GitLab Docker service. This is not a Maven official image and not a one-line retag.

```text
maven/
  Dockerfile
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Node 26 + JDK 17 + Maven | Mixed pipeline on one worker |
| docker-cli + `DOCKER_HOST` | Build or tag next to `docker:dind` |
| `/build` WORKDIR | Job checkout lands here |

```bash
docker build -t example.registry/ci/maven:node26-jdk17 -f Dockerfile .
```

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
