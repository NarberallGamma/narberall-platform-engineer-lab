# Liberica JRE 21 (CI)

**Business first:** Java 21 CI and runtime jobs share one Alpine musl JRE with CA certs and tzdata already in the layer.

This is Bellsoft Liberica OpenJRE 21.0.9 on Alpine musl, plus `ca-certificates` and `tzdata`. Not a one-line retag: the extra packages are the estate habit (TLS and timezone on every Java job).

```text
liberica-jre/
  Dockerfile
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Liberica 21 musl | Vendor pin used on shop Java jobs |
| `update-ca-certificates` | Corporate TLS on Alpine |
| Contrast | [`../jvm-base/`](../jvm-base/) is Temurin 11, one-line retag |

```bash
docker build -t example.registry/ci/liberica-jre:21.0.9 -f Dockerfile .
```

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
