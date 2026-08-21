FROM python:3.12-slim

RUN pip install --no-cache-dir flask aiogram requests

WORKDIR /app

# Copy skills and agents
COPY skills/ ./skills/
COPY ships-monitor-agent/ ./ships-monitor-agent/
COPY ships-dispatcher/ ./ships-dispatcher/

# Create memory directory (mounted as volume in K8s)
RUN mkdir -p /app/memory

ENV PYTHONUNBUFFERED=1

EXPOSE 8400

CMD ["python3", "skills/ships-api/server.py", "--port", "8400"]
