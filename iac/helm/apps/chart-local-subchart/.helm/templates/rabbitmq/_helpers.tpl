{{- define "rabbitmq.affinity" }}
{{- $ := index . 0 }}
{{- $relativeScope := index . 1 }}
{{- $val := index . 2 }}
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app: {{ $val }}
      topologyKey: kubernetes.io/hostname
{{- end }}
