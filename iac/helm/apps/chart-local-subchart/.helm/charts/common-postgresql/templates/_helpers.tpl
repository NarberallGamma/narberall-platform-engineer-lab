{{- define "common-postgresql.imagePullSecrets" }}
{{- with (include "fl.value" (list $ . $.Values.imagePullSecrets)) }}
imagePullSecrets: {{ . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "common-postgresql.affinity" }}
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

{{- define "common-postgresql.tolerations" }}
{{- with (include "fl.value" (list $ . $.Values.tolerations)) }}
tolerations: {{ . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "common-postgresql.nodeSelector" }}
{{- with (include "fl.value" (list $ . $.Values.nodeSelector)) }}
nodeSelector: {{ . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "common-postgresql.topologySpreadConstraints" }}
{{- with (include "fl.value" (list $ . $.Values.topologySpreadConstraints)) }}
topologySpreadConstraints: {{ . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "common-postgresql.priorityClassName" }}
{{- with (include "fl.value" (list $ . $.Values.priorityClassName)) }}
priorityClassName: {{ . }}
{{- end }}
{{- end }}
