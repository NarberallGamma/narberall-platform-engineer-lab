# Сборка из каталога cert-orchestrator (самодостаточный контекст):
#   cd cert-orchestrator && docker build -t cert-orchestrator:1.0 .
FROM python:3.11-alpine

RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    gettext \
    jq \
    openssh-client \
    openssl \
    procps \
    tzdata \
    && ARCH=$(uname -m) \
    && case "$ARCH" in x86_64) KARCH=amd64 ;; aarch64) KARCH=arm64 ;; *) echo "unsupported arch"; exit 1 ;; esac \
    && curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/v1.29.0/bin/linux/${KARCH}/kubectl" \
    && chmod +x /usr/local/bin/kubectl

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# vendor/certbot-regru
COPY vendor/certbot-regru /opt/certbot-regru
RUN pip install --no-cache-dir /opt/certbot-regru \
    && pip install --no-cache-dir certbot \
    && echo "certbot + certbot-regru installed"

COPY src/ ./

RUN mkdir -p /etc/cert-orchestrator /var/lib/cert-orchestrator

USER root

ENV CONFIG_FILE=/etc/cert-orchestrator/config.yaml
ENV PYTHONUNBUFFERED=1

HEALTHCHECK --interval=60s --timeout=15s --start-period=30s --retries=3 \
    CMD pgrep -f "python.*main.py" > /dev/null || exit 1

ENTRYPOINT ["python", "main.py"]
CMD ["daemon"]
