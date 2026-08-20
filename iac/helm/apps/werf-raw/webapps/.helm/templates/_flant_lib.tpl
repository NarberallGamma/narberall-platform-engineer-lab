{{- /* ## First variant: */ -}}
{{- /* {{- $app_name    := include "fl.value"  (list $ . .Values.app.name) }} */ -}}
{{- /* {{- $app_enabled := include "fl.isTrue" (list $ . .Values.app.enabled) }} */ -}}
{{- /* ## Second variant: */ -}}
{{- /* {{- $app_name    := .Values.app.name    | list $ . | include "fl.isTrue" }} */ -}}
{{- /* {{- $app_enabled := .Values.app.enabled | list $ . | include "fl.isTrue" }} */ -}}

{{- define "fl.value" }}
  {{- $ := index . 0 }}
  {{- $relativeScope := index . 1 }}
  {{- $val := index . 2 }}
  {{- $prefix := "" }}  {{- /* Optional */ -}}
  {{- $suffix := "" }}  {{- /* Optional */ -}}
  {{- if gt (len .) 3 }}
    {{- $optionalArgs := index . 3 }}
    {{- if hasKey $optionalArgs "prefix" }}
      {{- $prefix = $optionalArgs.prefix }}
    {{- end }}
    {{- if hasKey $optionalArgs "suffix" }}
      {{- $suffix = $optionalArgs.suffix }}
    {{- end }}
  {{- end }}

  {{- if kindIs "map" $val }}
    {{- $currentEnvVal := "" }}
    {{- if hasKey $val $.Values.global.env }}
      {{- $currentEnvVal = index $val $.Values.global.env }}
    {{- else if hasKey $val "_default" }}
      {{- $currentEnvVal = index $val "_default" }}
    {{- end }}
    {{- include "fl._renderValue" (list $ $relativeScope $currentEnvVal $prefix $suffix) }}
  {{- else }}
    {{- include "fl._renderValue" (list $ $relativeScope $val $prefix $suffix) }}
  {{- end }}
{{- end }}

{{- define "fl._renderValue" }}
  {{- $ := index . 0 }}
  {{- $relativeScope := index . 1 }}
  {{- $val := index . 2 }}
  {{- $prefix := index . 3 }}
  {{- $suffix := index . 4 }}

  {{- if and (not (kindIs "map" $val)) (not (kindIs "slice" $val)) }}
    {{- $valAsString := toString $val }}
    {{- if not (regexMatch "^<(nil|no value)>$" $valAsString) }}
      {{- $result := "" }}
      {{- if contains "{{" $valAsString }}
        {{- if empty $relativeScope }}
          {{- $relativeScope = $ }}  {{- /* tpl fails if $relativeScope is empty */ -}}
        {{- end }}
        {{- $result = tpl (printf "%s{{ with $.RelativeScope }}%s{{ end }}%s" $prefix $valAsString $suffix) (merge (dict "RelativeScope" $relativeScope) $) }}
      {{- else }}
        {{- $result = printf "%s%s%s" $prefix $valAsString $suffix }}
      {{- end }}
      {{- if ne $result "" }}{{ $result }}{{ end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "fl.isTrue" }}
  {{- ternary true "" (include "fl.value" . | eq "true") }}
{{- end }}

{{- define "fl.isFalse" }}
  {{- ternary "" true (include "fl.value" . | eq "true") }}
{{- end }}

{{- define "fl.generateConfigMapEnvVars" }}
  {{- $ := index . 0 }}
  {{- $relativeScope := index . 1 }}
  {{- $envs := index . 2 }}

  {{- range $envVarName, $envVarVal := $envs }}
    {{- $envVarVal = include "fl.value" (list $ $relativeScope $envVarVal) }}
    {{- if eq $envVarVal "___FL_THIS_ENV_VAR_WILL_BE_DEFINED_BUT_EMPTY___" }}
{{ $envVarName | quote }}: ""
    {{- else if ne $envVarVal "" }}
{{ $envVarName | quote }}: {{ $envVarVal | quote }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "fl.generateContainerEnvVars" }}
  {{- $ := index . 0 }}
  {{- $relativeScope := index . 1 }}
  {{- $envs := index . 2 }}

  {{- range $envVarName, $envVarVal := $envs }}
    {{- $envVarVal = include "fl.value" (list $ $relativeScope $envVarVal) }}
    {{- if eq $envVarVal "___FL_THIS_ENV_VAR_WILL_BE_DEFINED_BUT_EMPTY___" }}
- name: {{ $envVarName | quote }}
  value: ""
    {{- else if ne $envVarVal "" }}
- name: {{ $envVarName | quote }}
  value: {{ $envVarVal | quote }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "fl.generateSecretData" }}
  {{- $ := index . 0 }}
  {{- $relativeScope := index . 1 }}
  {{- $data := index . 2 }}

  {{- range $key, $value := $data }}
    {{- $value = include "fl.value" (list $ $relativeScope $value) }}
    {{- if eq $value "___FL_THIS_ENV_VAR_WILL_BE_DEFINED_BUT_EMPTY___" }}
{{ $key | quote }}: ""
    {{- else if ne $value "" }}
{{ $key | quote }}: {{ $value | b64enc | quote }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "fl.generateSecretEnvVars" }}
{{ include "fl.generateSecretData" . }}
{{- end }}
