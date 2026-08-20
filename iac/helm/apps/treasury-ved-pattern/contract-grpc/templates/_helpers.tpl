{{/*
Expand the name of the chart.
*/}}
{{- define "contract-grpc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Names are truncated at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If the release name contains the chart name, the release name is used as the full name.
*/}}
{{- define "contract-grpc.fullname" -}}
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
{{- define "contract-grpc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels. The extra gRPC Service includes this helper instead of hardcoded keys.
*/}}
{{- define "contract-grpc.labels" -}}
helm.sh/chart: {{ include "contract-grpc.chart" . }}
{{ include "contract-grpc.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "contract-grpc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "contract-grpc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
