ARG NODE_IMAGE_V22=example.registry/shop-app-infra/images/node:22-alpine
FROM $NODE_IMAGE_V22 as base
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
#RUN npm install
#COPY .npmrc package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
#RUN \
# if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
# elif [ -f package-lock.json ]; then npm ci; \
# elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
# else echo "Lockfile not found." && exit 1; \
# fi
COPY .npmrc package.json package-lock.json ./
RUN test -f package-lock.json || (echo "package-lock.json is required" && exit 1)
#RUN npm ci --no-audit
RUN npm ci --no-audit --no-fund


WORKDIR /app

ARG VERSION
ARG CLIENT_ID=shop
ARG CLIENT_SECRET=CHANGE_ME
ARG WS_ORIGIN_URL=https://shop-front:8080
ARG NEXT_PUBLIC_API_URL=https://dev.example.com

#ENV NEXT_PUBLIC_VERSION $VERSION
#ENV NEXT_PUBLIC_CLIENT_ID $CLIENT_ID
#ENV NEXT_PUBLIC_CLIENT_SECRET $CLIENT_SECRET
#ENV NEXT_PUBLIC_WS_ORIGIN_URL $WS_ORIGIN_URL
#ENV NEXT_PUBLIC_API_URL $NEXT_PUBLIC_API_URL

COPY . .

# Run tests before building the app
RUN  \
  if [ -f yarn.lock ]; then yarn run test; \
  elif [ -f package-lock.json ]; then npm run test;  \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run test; \
  else echo "Lockfile not found." && exit 1; \
  fi
