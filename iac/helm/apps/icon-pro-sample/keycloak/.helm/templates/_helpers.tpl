{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Helm required labels */}}
{{- define "labels" -}}
app.kubernetes.io/name: {{ template "name" . }}
helm.sh/chart: {{ template "chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.podLabels }}
{{ toYaml .Values.podLabels }}
{{- end }}
{{- end -}}

{{/* selectorLabels */}}
{{- define "selectorLabels" -}}
app.kubernetes.io/name: {{ template "name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "name" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Multiple ports for service
*/}}
{{- define "service-ports" -}}
{{- range $key, $value := . }}
- port: {{ $value.port }}
  targetPort: {{ $value.targetPort }}
  protocol: {{ $value.protocol | default "TCP" }}
  name: {{ $value.name }}
{{- end -}}
{{- end -}}

{{/*
Multiple ports for container
*/}}
{{- define "container-ports" -}}
{{- range $key, $value := . }}
- name: {{ $value.name }}
  protocol: {{ $value.protocol | default "TCP" }}
  containerPort: {{ $value.targetPort }}
{{- end -}}
{{- end -}}

{{/* podAnnotations */}}
{{- define "podAnnotations" -}}
{{- if .Values.podAnnotations }}
{{- toYaml .Values.podAnnotations }}
{{- end }}
{{- if .Values.metrics.podAnnotations }}
{{- toYaml .Values.metrics.podAnnotations }}
{{- end }}
{{- end -}}
