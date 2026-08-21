FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY panos_exporter.py .
USER nobody
EXPOSE 9654
ENTRYPOINT ["python", "panos_exporter.py"]
