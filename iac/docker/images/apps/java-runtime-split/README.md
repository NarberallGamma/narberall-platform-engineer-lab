# Gradle build + separate Liberica runtime

**Business first:** CI can **build the JAR on the runner** and ship a thin JRE image, instead of compiling inside every runtime tag. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Combined-image sibling: [`../java-gradle/`](../java-gradle/).

I used this pair when the pipeline already had a Gradle workspace: `Dockerfile` is the combined fallback (Gradle 8.14.3 → Liberica musl JRE 21), `Dockerfile.runtime` is the image that only copies `build/target/app-service.jar`. Fonts, `ca-certificates`, `JAVA_OPTS` / `JAVA_ARGS`, and a `noroot` user live on the runtime side. The JAR and any JKS are not in git.

```text
java-runtime-split/
  Dockerfile            # gradle:8.14.3-jdk21 → bellsoft/liberica-openjre-alpine-musl:21.0.8-12
  Dockerfile.runtime    # same Liberica pin, fonts, USER 1000:1000, java $JAVA_OPTS
```

```bash
# combined (needs the Gradle tree as context):
docker build -t example.registry/shop-app/java-runtime:local -f Dockerfile .

# runtime-only after a host Gradle build has written build/target/app-service.jar:
docker build -t example.registry/shop-app/java-runtime:local -f Dockerfile.runtime .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Two files | Same service, two CI paths. Combined vs pre-built JAR |
| Liberica musl 21.0.8-12 | Alpine JRE pin, not Temurin. Matches the CI JRE retag |
| Named `app-service.jar` | Output path is `build/target/`, not `build/libs/` |
| Fonts + `ca-certificates` | PDF / HTTPS on Alpine musl |
| `JAVA_OPTS` / `JAVA_ARGS` | Runtime flags without a rebuild |
| Commented JKS `COPY` | Truststore path is documented. The keystore file stays out |

## Honest gap

App source, the JAR, `cacerts`, and `client.jks` are not in this folder. `Dockerfile.runtime` still lists `COPY build/target/app-service.jar`. A rebuild fails until that artefact is in the context.

This is **not** [`../java-gradle/`](../java-gradle/). That file is Gradle 9 + Temurin + JDWP + `*plain.jar` strip in one image. This pair is the split-runtime mechanic.

**Keywords:** Gradle 8, Liberica JRE, Alpine musl, JAVA_OPTS, split runtime, fonts
