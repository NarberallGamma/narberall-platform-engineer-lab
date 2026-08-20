{{- define "lockbox.external.secrets" }}
{{- $lockbox := index . 0 }}
{{- $name := index . 1 }}
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ $name }}
  annotations:
    werf.io/weight: "-20"
spec:
  dataFrom:
{{- range $secret := $lockbox.secrets }}
  - extract:
      key: {{ $secret.name }}
{{- end }}
  refreshInterval: {{ $lockbox.refreshInterval }}
  secretStoreRef:
    kind: ClusterSecretStore
    name: {{ $lockbox.account }}
  target:
    creationPolicy: Owner
    name: {{ $name }}
{{- end }}