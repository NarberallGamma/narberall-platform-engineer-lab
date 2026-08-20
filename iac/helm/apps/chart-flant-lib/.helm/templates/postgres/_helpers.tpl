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
