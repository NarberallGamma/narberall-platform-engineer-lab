# Cloud.ru Status API → Prometheus exporter (по аналогии с cloudeye-exporter)
# Build stage
FROM golang:1.19-alpine AS builder

WORKDIR /build

# Copy go mod first, then download deps (go.sum will be generated if missing)
COPY src/go.mod ./
RUN go mod download

# Copy source and config
COPY src/main.go ./
COPY src/config.yml ./
RUN go mod tidy

# Build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -o cloud-status-exporter .

# Final stage
FROM alpine:3.18

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

COPY --from=builder /build/cloud-status-exporter .
COPY --from=builder /build/config.yml ./config.yml

# Non-root user (как у cloudeye-exporter)
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

EXPOSE 8087

ENTRYPOINT ["./cloud-status-exporter"]
CMD ["-config=/etc/cloud-status/config.yml"]
