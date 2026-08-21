# Runner image: docker login, rsync, git. Jobs call init.sh from before_script.
FROM alpine:3.22

RUN apk add --no-cache curl bash git rsync && \
    curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-26.1.1.tgz | tar xzv -C /tmp && \
    mv /tmp/docker/docker /usr/local/bin/ && rm -rf /tmp/docker && \
    mkdir -p /root/.docker

COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh
