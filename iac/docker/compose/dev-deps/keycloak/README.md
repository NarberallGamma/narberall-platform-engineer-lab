# Keycloak 20 (stock image + Postgres)

**Business first:** laptop SSO is **Keycloak 20.0.2 on Postgres** with `--import-realm`, not an in-memory `start-dev` that forgets users. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). SPI image compose: [`../../java-local-dev/keycloak-spi/`](../../java-local-dev/keycloak-spi/). Example realm on the image: [`../../../images/apps/keycloak/import/realm-export.json`](../../../images/apps/keycloak/import/realm-export.json).

I used this file when the shop did not need the custom SPI JAR. Admin password is `CHANGE_ME`. Host UI port 8282.

```text
keycloak/
  docker-compose.yml    # quay.io/keycloak/keycloak:20.0.2 + Postgres 14, import-realm bind
```

```bash
# from this directory, after copying an example realm to ./import/realm-export.json:
mkdir -p import
# copy the example realm from images/apps/keycloak/import/realm-export.json into ./import/
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `--import-realm` | Realm file is the contract, not a click-ops export after start |
| Dedicated Postgres | Same 14 pin as the shop DB file |
| Preview features + legacy user-profile SPI flag | Operated command line, not a trimmed demo |

## Honest gap

`./import/realm-export.json` is **not** in this folder. `docker compose up` fails on the bind until that file exists. The image tree has a 20-line example. I did not duplicate it here so the gap stays visible. This is **not** the custom `keycloak-spi` image.

**Keywords:** Keycloak 20.0.2, import-realm, Postgres, laptop SSO
