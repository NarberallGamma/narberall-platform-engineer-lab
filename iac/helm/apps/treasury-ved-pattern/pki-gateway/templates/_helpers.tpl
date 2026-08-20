{{/*
Expand the name of the chart.
*/}}
{{- define "pki-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Names are truncated at 63 chars because some Kubernetes fields follow the DNS naming spec.
If the release name contains the chart name, the release name is used as the full name.
*/}}
{{- define "pki-gateway.fullname" -}}
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
{{- define "pki-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pki-gateway.labels" -}}
helm.sh/chart: {{ include "pki-gateway.chart" . }}
{{ include "pki-gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pki-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pki-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
PVC storageClassName: persistence.storageClass.
"-" renders an empty string (cluster default StorageClass). Unset key omits storageClassName.
*/}}
{{- define "pki-gateway.bootstrapScriptConfigMapName" -}}
{{- printf "%s-bootstrap-script" (include "pki-gateway.fullname" .) }}
{{- end }}

{{- define "pki-gateway.pvc.storageClassSpec" -}}
{{- $p := . }}
{{- if hasKey $p "storageClass" }}
{{- if eq "-" ($p.storageClass | toString) }}
  storageClassName: ""
{{- else if $p.storageClass }}
  storageClassName: {{ $p.storageClass | quote }}
{{- end }}
{{- end }}
{{- end }}
