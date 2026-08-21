FROM node:18.12.0

WORKDIR /app

COPY npm.sh /npm.sh
RUN chmod +x /npm.sh

ENTRYPOINT ["sh", "/npm.sh"]
