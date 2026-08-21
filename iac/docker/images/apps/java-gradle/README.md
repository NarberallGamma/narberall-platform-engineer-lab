# Combined Gradle + JRE image

**Business first:** a shop Java service is one **multi-stage image** that compiles and runs, not a farm of per-service Dockerfiles. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Split-runtime sibling: [`../java-runtime-split/`](../java-runtime-split/).

I used this shape on the combined-image backends (Gradle 9 + Temurin 21, strip the `*plain.jar`, JDWP on 5005). The same two stages covered a dozen services. This folder is the richest copy. The Gradle project is not in git.

```text
java-gradle/
  Dockerfile    # gradle:9.2.0-jdk21 build → eclipse-temurin:21-jdk, USER 1000
```

```bash
# from this directory, after the Gradle tree is the build context:
docker build -t example.registry/shop-app/java-gradle:local \
  --build-arg VERSION=0.0.1 \
  --build-arg GRADLE_PARAMS='--no-daemon build -x test' \
  .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Two stages | Compile in Gradle, run a single `/app.jar` |
| `*plain.jar` strip | Spring Boot emits a plain jar next to the fat jar. The runtime copy must be the fat one |
| JDWP `*:5005` | DEV attach without a second image |
| `DOCKER_HOST` ARG | Default `tcp://172.17.0.1:2375` is the engine bridge, for Gradle tasks that talk to Docker |
| `USER 1000` | Non-root runtime |

## Honest gap

App source, `build.gradle`, and the JAR are not in this folder. `COPY . .` expects a real Gradle tree. A rebuild from this directory alone fails. Truststores (`client.jks`) stay out; the JKS-copy variants were not this mechanic.

This is **not** [`../java-runtime-split/`](../java-runtime-split/). That pair is a CI-built JAR plus a thin Liberica runtime. This file is the combined image.

**Keywords:** Gradle 9, JDK 21, Temurin, multi-stage, JDWP, Spring Boot fat jar
