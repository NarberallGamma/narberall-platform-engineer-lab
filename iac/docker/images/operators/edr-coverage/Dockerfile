FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# Source collectors (stage 2) sit beside this file and are invoked by the exporter
COPY merge3.py edr_exporter.py active-directory.py sbercloud-adv.py vkcloud.py vendor-edr.py edr_report.py ./
# Data directory is mounted from outside; the report and metrics are written here too
ENV EDR_DATA_DIR=/data
USER nobody
EXPOSE 9655
ENTRYPOINT ["python", "edr_exporter.py"]
