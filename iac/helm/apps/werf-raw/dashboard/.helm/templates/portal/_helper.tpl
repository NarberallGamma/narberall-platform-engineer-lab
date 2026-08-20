{{- define "affinity" }}
affinity:
{{- if eq .Values.werf.env "production" }}
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/production-apps
          operator: Exists
{{- end }}
{{- if eq .Values.werf.env "gra-production" }}
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/gra-production-apps
          operator: Exists
{{- end }}
{{- end }}

{{- define "tolerations" }}
{{- if eq .Values.werf.env "production" }}
tolerations:
- effect: NoExecute
  operator: Equal
  key: dedicated
  value: production-apps
{{- end }}
{{- if eq .Values.werf.env "gra-production" }}
tolerations:
- effect: NoExecute
  operator: Equal
  key: dedicated
  value: gra-production-apps
{{- end }}
{{- end }}

{{- define "priorityClassName" }}
{{- if eq .Values.werf.env "production" }}
priorityClassName: production-high
{{- end }}
{{- if eq .Values.werf.env "gra-production" }}
priorityClassName: production-medium
{{- end }}
{{- end }}
