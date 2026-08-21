ARG NODE_IMAGE_V20=example.registry/shop-app-infra/images/node:20-alpine
ARG NGINX_IMAGE=example.registry/shop-app-infra/images/nginx:1.21.0-alpine

FROM $NODE_IMAGE_V20 AS builder

WORKDIR /app
COPY . /app

RUN npm ci --force
RUN npm run build

# Bundle static assets with nginx
FROM $NGINX_IMAGE AS production
ENV NODE_ENV production

COPY --from=builder /app/build /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# on start: substitute env into config.js, then start nginx
CMD ["/bin/sh", "-c", "envsubst < /usr/share/nginx/html/config.template.js > /usr/share/nginx/html/config.js && nginx -g 'daemon off;'"]
