# JVM 11 JRE (CI pin)

**Business first:** Java 11 jobs share one **retag** of Eclipse Temurin 11 JRE. I did not maintain a custom JDK tree for that pin.

This folder is a one-line `FROM`. Hiring should treat it as a registry retag, not a generated tutorial.

```text
jvm-base/
  Dockerfile    # FROM eclipse-temurin:11-jre
```

```bash
docker build -t example.registry/ci/jvm-base:11-jre -f Dockerfile .
```

The Liberica 21 JRE pin lives in [`../liberica-jre/`](../liberica-jre/). Different major, different vendor.

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
