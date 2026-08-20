{{- define "init-logs" }}
- name: init-logs
  image: {{ index .Values.werf.image "init" }}
  command:
    - "bash"
    - "-c"
    - |
      mkdir -p /app/logs;
      touch /app/logs/log.json;
      chmod -R ugo+rw /app/logs;
  volumeMounts:
    - mountPath: /app/logs
      name: shared-logs
{{- end }}

{{- define "init-rabbitmq" }}
- name: init-rabbitmq
  image: {{ index .Values.werf.image "init" }}
  command:
    - "sh"
    - "-c"
    - "until wget http://${RABBIT_USER}:${RABBIT_PASSWORD}@${RABBIT_MQ_HOST}:15672/api/aliveness-test/%2F; do sleep 5; done;"
  env:
    - name: RABBIT_MQ_HOST
      valueFrom:
        configMapKeyRef:
          key: RBT_HOST
          name: {{ .Chart.Name }}-env
    - name: RABBIT_USER
      valueFrom:
        configMapKeyRef:
          key: RBT_USER
          name: {{ .Chart.Name }}-env
    - name: RABBIT_PASSWORD
      valueFrom:
        secretKeyRef:
          key: RBT_PASS
          name: {{ .Chart.Name }}-env

{{- end }}

{{- define "init-redis" }}
- name: init-redis
  image: {{ index .Values.werf.image "init" }}
  command:
    - "sh"
    - "-c"
    - "until redis-cli -h redis ping; do sleep 5; done;"

{{- end }}

{{- define "init-mysql" }}
- name: init-mysql
  image: {{ index .Values.werf.image "init" }}
  command:
    - "sh"
    - "-c"
    - "until mysql --host=$MYSQL_HOST --user=$MYSQL_USER --password=$MYSQL_PASSWORD --execute=\"SELECT 1;\"; do echo waiting for mysql; sleep 1; done; sleep 2;"
  env:
    - name: MYSQL_HOST
      valueFrom:
        configMapKeyRef:
          key: MYSQL_HOST
          name: {{ .Chart.Name }}-env
    - name: MYSQL_USER
      valueFrom:
        configMapKeyRef:
          key: MYSQL_USER
          name: {{ .Chart.Name }}-env
    - name: MYSQL_PASSWORD
      valueFrom:
        secretKeyRef:
          key: MYSQL_PASSWORD
          name: {{ .Chart.Name }}-env

{{- end }}

{{- define "init-psql-orders" }}
- name: init-psql-orders
  image: {{ index .Values.werf.image "init" }}
  command:
    - "sh"
    - "-c"
    - "until psql -c \"SELECT 1;\"; do echo waiting for psql; sleep 1; done; sleep 2;"
  env:
    - name: PGHOST
      valueFrom:
        configMapKeyRef:
          key: ORDERS_DELIVERY_MASTER_HOST_FOR_APPLICATION_USER
          name: {{ .Chart.Name }}-env
    - name: PGPORT
      valueFrom:
        configMapKeyRef:
          key: ORDERS_DELIVERY_PORT_FOR_APPLICATION_USER
          name: {{ .Chart.Name }}-env
    - name: PGDATABASE
      valueFrom:
        configMapKeyRef:
          key: ORDERS_DELIVERY_DB_NAME
          name: {{ .Chart.Name }}-env
    - name: PGUSER
      valueFrom:
        configMapKeyRef:
          key: ORDERS_DELIVERY_APPLICATION_USER
          name: {{ .Chart.Name }}-env
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          key: ORDERS_DELIVERY_APPLICATION_USER_PASS
          name: {{ .Chart.Name }}-env

{{- end }}

{{- define "init-psql-history" }}
- name: init-psql-history
  image: {{ index .Values.werf.image "init" }}
  command:
    - "sh"
    - "-c"
    - "until psql -c \"SELECT 1;\"; do echo waiting for psql; sleep 1; done; sleep 2;"
  env:
    - name: PGHOST
      valueFrom:
        configMapKeyRef:
          key: HISTORY_HOST_FOR_APPLICATION_USER
          name: {{ .Chart.Name }}-env
    - name: PGPORT
      valueFrom:
        configMapKeyRef:
          key: HISTORY_PORT_FOR_APPLICATION_USER
          name: {{ .Chart.Name }}-env
    - name: PGDATABASE
      valueFrom:
        configMapKeyRef:
          key: HISTORY_DB_NAME
          name: {{ .Chart.Name }}-env
    - name: PGUSER
      valueFrom:
        configMapKeyRef:
          key: HISTORY_APPLICATION_USER
          name: {{ .Chart.Name }}-env
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          key: HISTORY_APPLICATION_USER_PASS
          name: {{ .Chart.Name }}-env

{{- end }}

{{- define "init-psql-report" }}
- name: init-psql-report
  image: {{ index .Values.werf.image "init" }}
  command:
    - "sh"
    - "-c"
    - "until psql -c \"SELECT 1;\"; do echo waiting for psql; sleep 1; done; sleep 2;"
  env:
    - name: PGHOST
      valueFrom:
        configMapKeyRef:
          key: REPORT_HOST_FOR_APPLICATION_USER
          name: {{ .Chart.Name }}-env
    - name: PGPORT
      valueFrom:
        configMapKeyRef:
          key: REPORT_PORT_FOR_APPLICATION_USER
          name: {{ .Chart.Name }}-env
    - name: PGDATABASE
      valueFrom:
        configMapKeyRef:
          key: REPORT_DB_NAME
          name: {{ .Chart.Name }}-env
    - name: PGUSER
      valueFrom:
        configMapKeyRef:
          key: REPORT_APPLICATION_USER
          name: {{ .Chart.Name }}-env
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          key: REPORT_APPLICATION_USER_PASS
          name: {{ .Chart.Name }}-env

{{- end }}
