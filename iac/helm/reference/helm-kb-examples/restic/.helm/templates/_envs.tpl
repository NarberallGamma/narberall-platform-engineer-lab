{{- define "backup_envs" }}
- name: BACKUP_DMS_NAME
  value: {{ pluck .Values.werf.env .Values.backup_dms.name |  first | default .Values.backup_dms.name._default | quote }}
- name: BACKUP_DMS_KEY
  value: {{ pluck .Values.werf.env .Values.backup_dms.key |  first | default .Values.backup_dms.key._default | quote }}
- name: GOGC
  value: "1"
- name: PROJECT_PATH
  value: {{ pluck .Values.werf.env .Values.project_path |  first | default .Values.project_path._default | quote }}
- name: AUTH_KEY_PATH
  value: {{ pluck .Values.werf.env .Values.dms_key_path |  first | default .Values.dms_key_path._default | quote }}
- name: ENV
  value: {{ .Values.werf.env | quote }}
{{- range $i, $bucket := (pluck .Values.werf.env .Values.buckets) }}
{{- range $name, $obj := $bucket }}
- name : RESTIC_REPOSITORY_{{ $name }}
  value: {{ printf "%s%s" $obj.endpoint $obj.bucket |  quote }}
- name : RESTIC_PASSWORD_{{ $name }}
  value: {{ $obj.password | quote }}
- name : AWS_ACCESS_KEY_ID_{{ $name }}
  value: {{ $obj.access_key | quote }}
- name : AWS_SECRET_ACCESS_KEY_{{ $name }}
  value: {{ $obj.secret_key | quote }}
{{- end }}
{{- end }}
{{- end }}
