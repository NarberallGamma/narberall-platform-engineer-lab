{{- define "app.url" -}}
{{- if (index .Values.domain.url .Values.global.env) -}}
{{- index .Values.domain.url .Values.global.env -}}
{{- else -}}
{{- $base_url := (pluck .Values.global.env .Values.domain.domain_base | first | default .Values.domain.domain_base._default) -}}
{{- printf "%s.%s.%s" "kibana" .Values.global.env $base_url -}}
{{- end -}}
{{- end -}}

{{- define "app.tls.name" -}}
{{- if (index .Values.domain.tls.name .Values.global.env) -}}
{{- index .Values.domain.tls.name .Values.global.env  -}}
{{- else -}}
{{- printf "%s-tls" .Chart.Name  -}}
{{- end -}}
{{- end -}}