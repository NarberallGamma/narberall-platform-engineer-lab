# Keycloak + custom SPI image

**Business first:** shop SSO is a **Keycloak image that bakes a SPI JAR and an example realm**, not a vendor tag with a Bind-mount hope. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Compose that runs this image: [`../../../compose/java-local-dev/keycloak-spi/`](../../../compose/java-local-dev/keycloak-spi/). Stock Keycloak on the laptop: [`../../../compose/dev-deps/keycloak/`](../../../compose/dev-deps/keycloak/). Estate overlay: [`../../../../helm/apps/treasury-keycloak/`](../../../../helm/apps/treasury-keycloak/).

I used the two-stage file when the shop SPI had to land in `/opt/keycloak/providers/` before `start-dev`. Gradle 8.8 / JDK 11 builds the JAR. Keycloak 21.0.0 is the runtime pin. The realm JSON here is a 20-line example (`shop`, client `shop-app`, secret `CHANGE_ME`). The live export stays out.

```text
keycloak/
  Dockerfile                    # gradle:8.8.0-jdk11 → keycloak 21.0.0, CMD start-dev
  import/realm-export.json      # example realm only
```

```bash
# from this directory, after the SPI Gradle tree is the build context:
docker build -t example.registry/shop-app/keycloak-spi:local \
  --build-arg GRADLE_IMAGE_V11=example.registry/shop-app-infra/images/gradle:8.8.0-jdk11 \
  --build-arg KEYCLOAK_IMAGE=example.registry/shop-app-infra/images/keycloak-keycloak:21.0.0 \
  .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| SPI in `providers/` | Custom auth code is an image layer, not a volume after start |
| Example realm `COPY` | `start-dev` can `--import-realm` without a laptop JSON hunt |
| Registry ARGs | Build and runtime tags come from the shop infra catalog |

## Honest gap

SPI Java source, `build.gradle`, and the SNAPSHOT JAR are not in this folder. `COPY . .` on the Gradle stage expects that tree. A rebuild from this directory alone fails. The realm file is **not** a production export (no users, no live client secrets).

Stock Keycloak 20.0.2 without a SPI is [`../../../compose/dev-deps/keycloak/`](../../../compose/dev-deps/keycloak/). That compose still bind-mounts a realm path that is not next to the file.

**Keywords:** Keycloak 21, SPI, Gradle 8.8, realm import, start-dev
