{{- define "envoy.route" }}
{{- $envoy_common := index . 0 }}
{{- $service_config := index . 1 }}
{{- $env := index . 2 }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ $service_config.name }}
spec:
  parentRefs:
    - name: {{ pluck $env $envoy_common.gateway | first | default $envoy_common.gateway._default }}
  hostnames:
{{- $hostList := pluck $env $envoy_common.url  | first | default $envoy_common.url._default }}
{{- range $host := $hostList }}
    - {{ $host }}
{{- end }}
  rules:
    - backendRefs:
        - group: ""
          kind: Service
          name: {{ $service_config.name }}
          port: {{ $service_config.envoy.port }}
          weight: 1
      matches:
        - path:
            type: PathPrefix
            value: {{ $service_config.envoy.path }}
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              replacePrefixMatch: /
              type: ReplacePrefixMatch

{{- if eq $service_config.envoy.auth "jwt" }}
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  annotations:
  name: {{ $service_config.name }}
spec:
  jwt:
    providers:
    - name: keycloack
      remoteJWKS:
        uri: {{ pluck $env $envoy_common.remoteJWKS | first | default $envoy_common.remoteJWKS._default }}
      extractFrom:
        headers:
        - name: {{ $envoy_common.headers.name }}
          valuePrefix: {{ $envoy_common.headers.prefix }}
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: {{ $service_config.name }}
{{- end }}
{{- end }}
