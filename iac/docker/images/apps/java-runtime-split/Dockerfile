FROM mirror.gcr.io/gradle:8.14.3-jdk21 AS build
WORKDIR /src
COPY . .
ARG GRADLE_PARAMS="--no-daemon build"
RUN gradle $GRADLE_PARAMS

# final layer matches the separate runtime image
FROM bellsoft/liberica-openjre-alpine-musl:21.0.8-12
RUN apk add --no-cache ca-certificates tzdata && update-ca-certificates
COPY --from=build /src/build/target/app-service.jar /app.jar
USER 1000
ENTRYPOINT ["java","-jar","/app.jar"]
