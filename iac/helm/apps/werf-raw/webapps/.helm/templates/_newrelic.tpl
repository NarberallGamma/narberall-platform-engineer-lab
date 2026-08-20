{{ define "newrelic_configmap" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $.Chart.Name }}-newrelic-configmap
data:
  newrelic.ini: |
    extension=/usr/lib/newrelic-php5/agent/x64/newrelic-20210902.so
    [newrelic]
    newrelic.enabled = true
    newrelic.labels = {{ printf "environment: %s" .Values.werf.env | quote }}
    newrelic.license = {{ first (pluck .Values.werf.env .Values.newrelic.license) | default .Values.newrelic.license._default | quote }}
    newrelic.logfile = "/dev/stderr"
    newrelic.appname = {{ printf "webapps-%s" .Values.werf.env }}
    newrelic.daemon.logfile = "/dev/stderr"
    newrelic.daemon.port = /run/newrelic.sock
    newrelic.daemon.ssl = true
    newrelic.capture_params = false
    newrelic.error_collector.enable = true
    newrelic.error_collector.record_database_errors = true
    newrelic.error_collector.prioritize_api_errors = false
    newrelic.browser_monitoring.auto_instrument = true
    newrelic.transaction_tracer.enable = true
    newrelic.transaction_tracer.slow_sql = true
    newrelic.webtransaction.name.remove_trailing_path = false
    newrelic.cross_application_tracer.enabled = false
    newrelic.high_security = false
---
{{ end }}
