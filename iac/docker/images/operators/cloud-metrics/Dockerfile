# Build stage
FROM golang:1.19-alpine AS builder

WORKDIR /build

# Copy go mod files first
COPY src/go.mod src/go.sum ./
RUN go mod download

# Copy all source code maintaining directory structure
# Go module expects structure: github.com/huaweicloud/cloudeye-exporter/{collector,logs}
COPY src/main.go ./
COPY src/collector ./collector/
COPY src/logs ./logs/
COPY src/clouds.yml ./
COPY src/endpoints.yml ./
COPY src/logs.yml ./
COPY src/metric.yml ./
COPY src/i18n.json ./
COPY src/unit_standard_transform.json ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -o cloudeye-exporter .

# Final stage
FROM alpine:3.18

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/cloudeye-exporter .

# Copy default config files (optional, will be overridden by ConfigMap)
COPY --from=builder /build/clouds.yml /app/clouds.yml
COPY --from=builder /build/logs.yml /app/logs.yml
COPY --from=builder /build/metric.yml /app/metric.yml
COPY --from=builder /build/endpoints.yml /app/endpoints.yml
COPY --from=builder /build/i18n.json /app/i18n.json
COPY --from=builder /build/unit_standard_transform.json /app/unit_standard_transform.json

# Create non-root user (use different UID/GID to avoid conflicts)
# Alpine already has nobody:65534, so we use 1000:1000
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

EXPOSE 8087

ENTRYPOINT ["./cloudeye-exporter"]
CMD ["-config=/etc/cloudeye/clouds.yml"]
