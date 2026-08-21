# CCE/ECS Cluster Hibernate/Awake Management Docker Image
FROM python:3.11-alpine

# Install system dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
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
COPY src/swagger.json ./

# Create logs directory with proper permissions
RUN mkdir -p /app/logs \
    && echo "Logs directory created"

# Create non-root user for security
RUN adduser -D -s /bin/sh clusteradmin \
    && chown -R clusteradmin:clusteradmin /app \
    && echo "User clusteradmin created"

# Switch to non-root user
USER clusteradmin

# Expose API port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8080/health', timeout=5)" || exit 1

# Default entry point
ENTRYPOINT ["python", "main.py"]
