{{/*
Expand the name of the chart.
*/}}
{{- define "cryptopro.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "cryptopro.fullname" -}}
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

{{- define "cryptopro.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "cryptopro.labels" -}}
helm.sh/chart: {{ include "cryptopro.chart" . }}
{{ include "cryptopro.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "cryptopro.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cryptopro.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
storageClassName: set persistence.storageClass for the cluster; "-" renders an empty string (default StorageClass); omit the key to skip the field.
*/}}
{{- define "cryptopro.pvc.storageClassSpec" -}}
{{- $p := . }}
{{- if hasKey $p "storageClass" }}
{{- if eq "-" ($p.storageClass | toString) }}
  storageClassName: ""
{{- else if $p.storageClass }}
  storageClassName: {{ $p.storageClass | quote }}
{{- end }}
{{- end }}
{{- end }}
