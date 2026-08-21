ARG GRADLE_IMAGE_V21=mirror.gcr.io/gradle:9.2.0-jdk21
FROM $GRADLE_IMAGE_V21 as build
COPY . .
ARG DOCKER_HOST="tcp://172.17.0.1:2375"
ARG GRADLE_PARAMS="--no-daemon build -x test"
RUN gradle $GRADLE_PARAMS
RUN rm ./build/libs/*plain.jar || true
RUN cp ./build/libs/*.jar /app.jar

ARG RUNTIME_IMAGE_V21=mirror.gcr.io/eclipse-temurin:21-jdk
FROM $RUNTIME_IMAGE_V21
COPY --from=build /app.jar /
USER 1000
ARG VERSION
ENV VERSION=$VERSION
ENTRYPOINT ["java","-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005","-jar","/app.jar"]
