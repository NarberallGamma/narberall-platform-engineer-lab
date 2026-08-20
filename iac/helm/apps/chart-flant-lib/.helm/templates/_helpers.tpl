{{- define "init-psql" }}
- name: init-psql
  image: {{ .Values.werf.image.init }}
  command:
    - "sh"
    - "-c"
    - "until psql -c \"SELECT 1;\"; do echo waiting for psql; sleep 1; done; sleep 2;"
  env:
    - name: PGHOST
      valueFrom:
        secretKeyRef:
          key: DB_HOST
          name: {{ .Chart.Name }}-env
    - name: PGPORT
      valueFrom:
        secretKeyRef:
          key: DB_PORT
          name: {{ .Chart.Name }}-env
    - name: PGDATABASE
      valueFrom:
        secretKeyRef:
          key: DB_NAME
          name: {{ .Chart.Name }}-env
    - name: PGUSER
      valueFrom:
        secretKeyRef:
          key: DB_USER
          name: {{ .Chart.Name }}-env
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          key: DB_PASS
          name: {{ .Chart.Name }}-env
{{- end }}

{{- define "imagePullSecrets" }}
{{- with (include "fl.value" (list $ . $.Values.imagePullSecrets)) }}
imagePullSecrets: {{ . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "affinity" }}
{{- $ := index . 0 }}
{{- $relativeScope := index . 1 }}
{{- $val := index . 2 }}
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 1
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - {{ $val }}
        topologyKey: kubernetes.io/hostname
{{- end }}

{{- define "tolerations" }}
{{- with (include "fl.value" (list $ . $.Values.tolerations)) }}
tolerations: {{ . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "nodeSelector" }}
{{- with (include "fl.value" (list $ . $.Values.nodeSelector)) }}
nodeSelector: {{ . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "topologySpreadConstraints" }}
{{- with (include "fl.value" (list $ . $.Values.topologySpreadConstraints)) }}
topologySpreadConstraints: {{ . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "priorityClassName" }}
{{- with (include "fl.value" (list $ . $.Values.priorityClassName)) }}
priorityClassName: {{ . }}
{{- end }}
{{- end }}

{{- define "postgresql.affinity" }}
{{- $ := index . 0 }}
{{- $relativeScope := index . 1 }}
{{- $val := index . 2 }}
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 1
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - {{ $val }}
        topologyKey: kubernetes.io/hostname
{{- end }}
