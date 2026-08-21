# Java app stack (service enabled)

**Business first:** this file is the laptop stack where the **Spring app is actually running**, next to Postgres, MinIO, and Keycloak. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Deps-only sibling: [`../java-local-stack/`](../java-local-stack/).

I used this shape when the chat-class service had to boot against local SSO and S3. JDWP 5005 is published. Keycloak is on 8284 so it does not collide with the deps-only stack.

```text
java-app-stack/
  docker-compose.yml    # chat-app:latest + PG + MinIO + Keycloak 20.0.2
```

```bash
# from this directory, after chat-app:latest is built and
# ./keycloak/import/realm-export.json exists:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| App `depends_on` | Real start order: DB, MinIO, Keycloak |
| S3 env on the app | Access key, bucket, region, address |
| JDWP `5005` | Same DEV attach habit as the Gradle image |

## Honest gap

`chat-app:latest` is not built from this folder (no Dockerfile here). `./keycloak/import/realm-export.json` is **not** here. Host port **5438** is published on both `chat-postgres` and `keycloak-postgres` (source bug, kept). MinIO still uses the old `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` names from the source file.

**Keywords:** Spring app, Keycloak, MinIO, JDWP, laptop
