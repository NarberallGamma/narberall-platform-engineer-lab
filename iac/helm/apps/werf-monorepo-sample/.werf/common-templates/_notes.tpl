{{- define "utils.notes" }}
{{- $name := index . 0 }}
{{- $images := index . 1 }}

{{ $name }}
Release images summary:

{{ range $k, $v := $images }}
{{$k}} = {{ $v }}
{{- end }}
{{- end }}