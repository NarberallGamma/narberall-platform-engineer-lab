FROM python:3.12.3-slim

WORKDIR /app

COPY . .

RUN pip install -r requirements.txt

ENV PYTHONUNBUFFERED=1

EXPOSE 8401

ENTRYPOINT ["python"]
CMD ["__main__.py"]
