{{/*
Expand the name of the chart.
*/}}
{{- define "policy-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Names are truncated at 63 chars because some Kubernetes fields follow the DNS naming spec.
If the release name contains the chart name, the release name is used as the full name.
*/}}
{{- define "policy-gateway.fullname" -}}
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
Create chart name and version as used in the chart label.
*/}}
{{- define "policy-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "policy-gateway.labels" -}}
helm.sh/chart: {{ include "policy-gateway.chart" . }}
{{ include "policy-gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "policy-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "policy-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
PVC storageClassName: accept storageClassName (this chart) or storageClass (cryptopro).
"-" renders an empty string (cluster default StorageClass). Unset key omits storageClassName.
*/}}
{{- define "policy-gateway.bootstrapScriptConfigMapName" -}}
{{- printf "%s-bootstrap-script" (include "policy-gateway.fullname" .) }}
{{- end }}

{{- define "policy-gateway.pvc.storageClassSpec" -}}
{{- $p := . }}
{{- $sc := $p.storageClassName | default $p.storageClass }}
{{- if $sc }}
{{- if eq "-" ($sc | toString) }}
  storageClassName: ""
{{- else }}
  storageClassName: {{ $sc | quote }}
{{- end }}
{{- end }}
{{- end }}
