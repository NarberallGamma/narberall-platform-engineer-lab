FROM nginx:1.23-alpine

# TLS material is generated at image build (no committed keys)
RUN apk add --no-cache openssl \
    && openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/server.key \
        -out /etc/nginx/server.crt \
        -subj "/CN=shop-app.example.com"

ADD nginx.conf /etc/nginx/conf.d/default.conf
