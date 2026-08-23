# Dockerfile for a static nginx site on Ubuntu
FROM ubuntu:24.04

# Image metadata
LABEL maintainer="ops@example.com" \
      description="Static corporate site" \
      version="1.0"

# Install nginx and required tools in one layer
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        nginx \
        curl \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -rf /var/www/html/* && \
    rm -f /etc/nginx/sites-enabled/default && \
    mkdir -p /var/www/html && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Copy static site files
COPY index.html styles.css script.js content.json /var/www/html/
COPY logo.jpg logo.svg logo_full-2.svg /var/www/html/

# Copy custom nginx config
COPY docker/nginx.conf /etc/nginx/sites-enabled/default

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Expose port 80
EXPOSE 80

# Disable nginx daemon mode and run in the foreground
CMD ["nginx", "-g", "daemon off;"]

