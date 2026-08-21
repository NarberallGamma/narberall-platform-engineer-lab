# MinIO (laptop object store)

**Business first:** shop S3 on the laptop is **one MinIO** with a console, not a fake `file://` bucket. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this file when a Java service needed S3-compatible storage next to the app. API 9000, console 9001. Root keys are `CHANGE_ME`.

```text
minio/
  docker-compose.yml    # minio/minio:latest, server /data, console :9001
```

```bash
# from this directory, after setting MINIO_ROOT_* to a local value:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Console port | Operators debug buckets without an extra UI image |
| `CHANGE_ME` keys | No live access key in git |

## Honest gap

No init bucket, no TLS. The richer stack (healthcheck + named volume) is [`../../java-local-dev/java-local-stack/`](../../java-local-dev/java-local-stack/).

**Keywords:** MinIO, S3, laptop, console
