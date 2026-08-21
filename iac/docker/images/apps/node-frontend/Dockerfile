# === base ===
ARG NODE_IMAGE_V22=example.registry/shop-app-infra/images/node:22-alpine
FROM $NODE_IMAGE_V22 as base

WORKDIR /app

# === deps: install from lockfile only ===
FROM base AS deps
COPY .npmrc package.json package-lock.json ./

RUN npm ci --no-audit --no-fund

# === builder ===
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# build-time public env
ARG VERSION
ARG CLIENT_ID=shop
ARG CLIENT_SECRET=CHANGE_ME
ARG WS_ORIGIN_URL=https://shop-front:8080
ARG NEXT_PUBLIC_API_URL=https://shop.example.com
ARG NODE_OPTIONS="--max-old-space-size=4096"
ENV NEXT_PUBLIC_VERSION=$VERSION \
    NEXT_PUBLIC_CLIENT_ID=$CLIENT_ID \
    NEXT_PUBLIC_CLIENT_SECRET=$CLIENT_SECRET \
    NEXT_PUBLIC_WS_ORIGIN_URL=$WS_ORIGIN_URL \
    NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL \
    NODE_OPTIONS=$NODE_OPTIONS

RUN npm run build

# === runner: thin runtime ===
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production



RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs

# next standalone artefacts
COPY --from=builder /app/public ./public
RUN mkdir .next && chown nextjs:nodejs .next
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT=3000

# server.js is emitted by next standalone
CMD ["node", "server.js"]
