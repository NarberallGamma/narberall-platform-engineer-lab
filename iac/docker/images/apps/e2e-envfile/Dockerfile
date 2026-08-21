ARG NODE_IMAGE_V20=example.registry/shop-app-infra/images/node:20-alpine
ARG NGINX_IMAGE=example.registry/shop-app-infra/images/nginx:1.21.0-alpine
ARG NPM_COMMAND="npm run build"
ARG E2E_ENV_FILE=.env.e2e.dev
ARG E2E_TEST_BASE_URL
ARG E2E_TEST_NAMES

FROM $NODE_IMAGE_V20 AS builder

# ARG before FROM is visible only in FROM. Re-declare inside the stage so CI --build-arg reaches ENV.
ARG E2E_ENV_FILE=.env.e2e.dev
ARG E2E_TEST_BASE_URL
ARG E2E_TEST_NAMES

ENV CI=true
ENV E2E_ENV_FILE=$E2E_ENV_FILE
ENV E2E_TEST_BASE_URL=$E2E_TEST_BASE_URL
ENV E2E_TEST_NAMES=$E2E_TEST_NAMES
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser

WORKDIR /app
COPY . /app

RUN apk add --no-cache chromium nss freetype harfbuzz ca-certificates ttf-freefont

# Stand accounts live in .env.e2e.<stand> (in git), not as ENV in this file.
# Copy the chosen file to .env.e2e. That is what playwright.config.ts dotenv loads.
# E2E_TEST_BASE_URL from the job overrides the file (dotenv does not clobber process.env).
# Empty value is unset so it does not force localhost.
RUN set -e; \
    cp "$E2E_ENV_FILE" .env.e2e; \
    case "$E2E_TEST_BASE_URL" in \
      http://*|https://*) ;; \
      '') unset E2E_TEST_BASE_URL ;; \
      *) export E2E_TEST_BASE_URL="https://$E2E_TEST_BASE_URL" ;; \
    esac; \
    echo "e2e: env-file $E2E_ENV_FILE, stand ${E2E_TEST_BASE_URL:-from file}"; \
    npm ci --force && npm run test:e2e
