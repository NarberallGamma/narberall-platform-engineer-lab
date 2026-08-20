{{- define "safe_printf" }}
  {{- $format  := index . 0 }}
  {{- $val := index . 1 }}
  {{- $format | contains "%s" | ternary (printf $format $val) $format }}
{{- end }}

{{- define "server_alias" }}
{{- $ := index . 0 }}
{{- $app_urls  := index . 1 }}
{{- $env := index . 2 }}

{{- range $i, $app_url := $app_urls }}
{{- if $i }},{{ end }}
{{- printf "www.%s" (include "fl.value" (list $ . $app_url.host)) }}
{{- end }}
{{- end }}

{{- define "server_name" }}
{{- $ := index . 0 }}
{{- $app_urls  := index . 1 }}
{{- $env := index . 2 }}

{{- range $i, $app_url := $app_urls }}
{{- if $i }} {{ end }}
{{- printf "~^(?<subdomain>.+)\\.%s$" (include "fl.value" (list $ . $app_url.host)) }}
{{- if $app_url.host2 }}
{{- printf " ~^(?<subdomain>.+)\\.%s$" (include "fl.value" (list $ . $app_url.host2)) }}
{{- end }}
{{- end }}
{{- end }}

{{- define "priorityClassName" }}
{{- if eq $.Values.werf.env "production" }}
priorityClassName: production-high
{{- end }}
{{- end }}

{{- define "affinity" }}
{{- with (include "fl.value" (list $ . $.Values.affinity)) }}
affinity: {{ . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "tolerations" }}
{{- with (include "fl.value" (list $ . $.Values.tolerations)) }}
tolerations: {{ . | nindent 2 }}
{{- end }}
{{- end }}
