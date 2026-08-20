{{/*
Istio peer-auth + VPS egress chart helpers
*/}}
{{- define "istio-peer-authentication.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "istio.vpsEgress.gatewayFullName" -}}
{{- .Values.vpsEgress.gateway.name | default "egress-vps-gateway" -}}
{{- end -}}

{{- define "istio.vpsEgress.gatewayNamespaced" -}}
{{- printf "%s/%s" (.Values.vpsEgress.gateway.namespace | default "istio-system") (include "istio.vpsEgress.gatewayFullName" .) -}}
{{- end -}}

{{- define "istio.vpsEgress.externalServiceEntryName" -}}
{{- $host := .host -}}
{{- $sanitized := regexReplaceAll "[^a-z0-9-]" (lower $host) "-" -}}
{{- $sanitized = regexReplaceAll "-+" $sanitized "-" -}}
{{- $sanitized = trimAll "-" $sanitized -}}
{{- printf "external-%s" $sanitized | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "istio.vpsEgress.routeEnabled" -}}
{{- if hasKey . "enabled" -}}
{{- .enabled -}}
{{- else -}}
true
{{- end -}}
{{- end -}}

{{- define "istio.vpsEgress.routeNamespace" -}}
{{- .route.namespace | default .root.Values.vpsEgress.appNamespace -}}
{{- end -}}
