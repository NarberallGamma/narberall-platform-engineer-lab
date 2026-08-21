FROM node:26-alpine

RUN apk add --no-cache \
    openjdk17 \
    maven \
    docker-cli \
    curl \
    bash \
    git \
    && rm -rf /var/cache/apk/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk
ENV PATH=$PATH:$JAVA_HOME/bin

ENV DOCKER_HOST=tcp://docker:2375
ENV DOCKER_TLS_CERTDIR=""

WORKDIR /build

CMD ["/bin/bash"]