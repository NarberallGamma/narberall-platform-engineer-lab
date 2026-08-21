FROM python:3.12-slim

RUN pip install --no-cache-dir aiogram requests

WORKDIR /app

COPY skills/ships-api/bridge.py ./
COPY skills/ships-api/scripts/ ./scripts/

RUN mkdir -p /app/memory

ENV PYTHONUNBUFFERED=1

CMD ["python3", "bridge.py"]
