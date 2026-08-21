FROM apache/nifi:2.6.0

ENV NIFI_LIB_DIR=/opt/nifi/nifi-current/lib

RUN curl -L -o ${NIFI_LIB_DIR}/postgresql.jar \
    https://jdbc.postgresql.org/download/postgresql-42.7.8.jar

COPY cacerts /usr/lib/jvm/jdk-21.0.8-bellsoft-aarch64/lib/security/
