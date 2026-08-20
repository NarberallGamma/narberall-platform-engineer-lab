# vi:syntax=yaml
# vi:filetype=yaml

{{- define "backup_envs" }}
{{- range $key, $value := .Values.psql }}
- name: {{ $key | upper }}
  value: {{ $key }}
{{- if $value.host }}
- name: {{ $key | upper }}_HOST
  value: {{ $value.host }}
{{- end }}
{{- if $value.port }}
- name: {{ $key | upper }}_PORT
  value: {{ $value.port }}
{{- end }}
{{- if $value.database }}
- name: {{ $key | upper }}_DATABASE
  value: {{ $value.database }}
{{- end }}
{{- if $value.user }}
- name: {{ $key | upper }}_USER
  value: {{ $value.user }}
{{- end }}
{{- if $value.password }}
- name: {{ $key | upper }}_PASSWORD
  value: {{ $value.password }}
{{- end }}
{{- end }}
{{- end }}
