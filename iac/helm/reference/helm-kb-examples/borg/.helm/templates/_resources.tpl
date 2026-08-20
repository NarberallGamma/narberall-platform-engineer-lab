# vi:syntax=yaml
# vi:filetype=yaml

{{- define "resources_crons" }}
resources:
  requests:
    memory: {{ first (pluck .Values.global.env .Values.resources.crons.requests.memory) | default .Values.resources.crons.requests.memory._default | quote }}
    cpu: {{ first (pluck .Values.global.env .Values.resources.crons.requests.cpu) | default .Values.resources.crons.requests.cpu._default | quote }}
  limits:
    memory: {{ first (pluck .Values.global.env .Values.resources.crons.limits.memory) | default .Values.resources.crons.limits.memory._default | quote }}
{{- end }}
