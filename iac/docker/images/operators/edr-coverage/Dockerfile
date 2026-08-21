FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# Сборщики источников (этап 2) лежат рядом и вызываются экспортером
COPY merge3.py edr_exporter.py active-directory.py sbercloud-adv.py vkcloud.py vendor-edr.py edr_report.py ./
# Каталог данных монтируется снаружи; сюда же пишутся отчёт и метрики
ENV EDR_DATA_DIR=/data
USER nobody
EXPOSE 9655
ENTRYPOINT ["python", "edr_exporter.py"]
