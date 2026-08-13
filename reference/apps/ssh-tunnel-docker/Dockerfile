FROM alpine:3.19

RUN apk add --no-cache openssh-client nginx nginx-mod-stream

# nginx in Alpine: default runs as daemon; we need foreground and stream only
RUN mkdir -p /run/nginx && \
    sed -i 's/^daemon off;/daemon off;/' /etc/nginx/nginx.conf 2>/dev/null || true

COPY nginx-balancer.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENV SSH_HOST="" SSH_USER="" SSH_KEY_PATH="/config/key" REMOTE_PORT="10443" ROTATE_MIN="10"

EXPOSE 10808

ENTRYPOINT ["/entrypoint.sh"]
