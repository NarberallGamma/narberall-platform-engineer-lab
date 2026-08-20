# vi:syntax=yaml
# vi:filetype=yaml

{{- define "resources_nginx" }}
resources:
  requests:
    cpu: {{ pluck .Values.werf.env .Values.resources.nginx.requests.cpu | first | default .Values.resources.nginx.requests.cpu._default }}
    memory: {{ pluck .Values.werf.env .Values.resources.nginx.requests.memory | first | default .Values.resources.nginx.requests.memory._default }}
  limits:
    memory: {{ pluck .Values.werf.env .Values.resources.nginx.limits.memory | first | default .Values.resources.nginx.limits.memory._default }}
{{- end }}

{{- define "resources_app" }}
resources:
  requests:
    cpu: {{ pluck .Values.werf.env .Values.resources.php_backend.requests.cpu | first | default .Values.resources.php_backend.requests.cpu._default }}
    memory: {{ pluck .Values.werf.env .Values.resources.php_backend.requests.memory | first | default .Values.resources.php_backend.requests.memory._default }}
  limits:
    memory: {{ pluck .Values.werf.env .Values.resources.php_backend.limits.memory | first | default .Values.resources.php_backend.limits.memory._default }}
{{- end }}

{{- define "resources_crons" }}
resources:
  requests:
    cpu: {{ pluck .Values.werf.env .Values.resources.php_cron.requests.cpu | first | default .Values.resources.php_cron.requests.cpu._default }}
    memory: {{ pluck .Values.werf.env .Values.resources.php_cron.requests.memory | first | default .Values.resources.php_cron.requests.memory._default }}
  limits:
    memory: {{ pluck .Values.werf.env .Values.resources.php_cron.limits.memory | first | default .Values.resources.php_cron.limits.memory._default }}
{{- end }}

{{- define "resources_worker" }}
resources:
  requests:
    cpu: {{ pluck .Values.werf.env .Values.resources.php_worker.requests.cpu | first | default .Values.resources.php_worker.requests.cpu._default }}
    memory: {{ pluck .Values.werf.env .Values.resources.php_worker.requests.memory | first | default .Values.resources.php_worker.requests.memory._default }}
  limits:
    memory: {{ pluck .Values.werf.env .Values.resources.php_worker.limits.memory | first | default .Values.resources.php_worker.limits.memory._default }}
{{- end }}
