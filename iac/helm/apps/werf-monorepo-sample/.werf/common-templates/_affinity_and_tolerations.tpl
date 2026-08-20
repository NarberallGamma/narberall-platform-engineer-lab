{{- define "affinity" }}
{{- $name := index . 1 }}
{{- with index . 0 }}
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - podAffinityTerm:
        labelSelector:
          matchLabels:
            app: {{ $name }}
        topologyKey: kubernetes.io/hostname
      weight: 100
{{- if or (eq .Values.werf.env "production") (eq .Values.werf.env "production-aws") }}
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/production
          operator: Exists
        - key: node-role.kubernetes.io/prod-nodes
          operator: Exists
{{- end }}
{{- end }}
{{- end }}

{{- define "tolerations" }}
{{- if or (eq .Values.werf.env "production") (eq .Values.werf.env "production-aws") }}
tolerations:
- effect: NoExecute
  operator: Equal
  key: dedicated
  value: production
{{- end }}
{{- end }}

{{- define "priorityClassName" }}
{{- if or (eq .Values.werf.env "production") (eq .Values.werf.env "production-aws") }}
priorityClassName: production-medium
{{- end }}
{{- end }}
