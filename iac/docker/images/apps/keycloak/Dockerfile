ARG GRADLE_IMAGE_V11=example.registry/shop-app-infra/images/gradle:8.8.0-jdk11
ARG KEYCLOAK_IMAGE=example.registry/shop-app-infra/images/keycloak-keycloak:21.0.0

FROM $GRADLE_IMAGE_V11 as build
COPY . .
RUN gradle build 

FROM $KEYCLOAK_IMAGE
COPY --from=build /home/gradle/build/libs/keycloak-spi-*-SNAPSHOT.jar /opt/keycloak/providers/
COPY ./keycloak/import/realm-export.json /opt/keycloak/data/import/realm-export.json
CMD ["start-dev"]
