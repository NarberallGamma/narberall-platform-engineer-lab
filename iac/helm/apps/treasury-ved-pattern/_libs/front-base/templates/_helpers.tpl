{{/*
Expand the name of the chart.
*/}}
{{- define "front-base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Read variables from values
*/}}
{{- define "envify" -}}
{{- $prefix := index . 0 -}}
{{- $value := index . 1 -}}
{{- if kindIs "map" $value -}}
  {{- range $k, $v := $value -}}
    {{- template "envify" (list (printf "%s.%s" $prefix $k) $v) -}}
  {{- end -}}
{{- else -}}
{{ trimPrefix "." $prefix | nindent 2 }}: {{ $value | toString | b64enc | default ("" | quote) }}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "front-base.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "front-base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "front-base.labels" -}}
helm.sh/chart: {{ include "front-base.chart" . }}
{{ include "front-base.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "front-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "front-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "front-base.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "front-base.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
