# SSL Certificate Monitoring Docker Image
FROM python:3.11-alpine

# Install system dependencies
RUN apk add --no-cache \
    openssl \
    ca-certificates \
    tzdata \
    procps \
    && echo "System dependencies installed"

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY src/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt \
    && echo "Python dependencies installed"

# Copy application files from src directory
COPY src/*.py ./

# Create logs directory
RUN mkdir -p /app/logs \
    && echo "Logs directory created"

# Create non-root user for security
RUN adduser -D -s /bin/sh certmonitor \
    && chown -R certmonitor:certmonitor /app \
    && echo "User certmonitor created"

USER certmonitor

# Health check - проверяем что приложение работает (простая проверка процесса)
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD pgrep -f "python.*main.py" > /dev/null || exit 1

# Entry point for SSL monitoring (long-running mode)
ENTRYPOINT ["python", "main.py"]
