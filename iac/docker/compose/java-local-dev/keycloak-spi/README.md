# Keycloak with custom SPI image

**Business first:** laptop SSO with shop extensions is **the SPI image plus Postgres**, not the stock quay tag. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Image: [`../../../images/apps/keycloak/`](../../../images/apps/keycloak/). Stock Keycloak: [`../../dev-deps/keycloak/`](../../dev-deps/keycloak/).

I used this file when `KC_LOG_LEVEL=DEBUG` and the custom providers JAR had to be in the image. Service name `keycloak-spi`. Host port 8282.

```text
keycloak-spi/
  docker-compose.yml    # keycloak-spi:latest + Postgres 14, import-realm bind
```

```bash
# build the SPI image first (needs the Gradle tree; see the image README), then:
# place realm-export.json at ./keycloak/import/realm-export.json
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Image `keycloak-spi:latest` | Same mechanic as [`../../../images/apps/keycloak/`](../../../images/apps/keycloak/) |
| `KC_LOG_LEVEL: DEBUG` | SPI work on the laptop |
| Same `--import-realm` flags | Command line matches the stock deps file |

## Honest gap

`keycloak-spi:latest` is not built from this folder. `./keycloak/import/realm-export.json` is **not** here. `docker compose up` fails on the bind until that file exists. Example realm: [`../../../images/apps/keycloak/import/realm-export.json`](../../../images/apps/keycloak/import/realm-export.json).

**Keywords:** Keycloak SPI, DEBUG, import-realm, custom image
