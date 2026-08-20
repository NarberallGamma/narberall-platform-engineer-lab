{{- define "lockbox.external.secrets.rds" }}
{{- $lockbox := index . 0 }}
{{- $name := index . 1 }}
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ $name }}-rds
  annotations:
    werf.io/weight: "-20"
spec:
  dataFrom:
{{- range $secret := $lockbox.secrets_rds }}
  - extract:
      key: {{ $secret.name }}
{{- end }}
  refreshInterval: {{ $lockbox.refreshInterval }}
  secretStoreRef:
    kind: ClusterSecretStore
    name: {{ $lockbox.account }}
  target:
    creationPolicy: Owner
    name: {{ $name }}-rds
    {{- if $lockbox.targetTemplate }}
    template:
      engineVersion: {{ $lockbox.targetTemplate.engineVersion }}
      data:
        {{- range $key, $value := $lockbox.targetTemplate.data }}
        {{ $key }}: '{{ $value }}'
        {{- end }}
    {{- end }}
{{- end }}