{{/*
Convert variable to helm parameters recursively
Usage:
    {{- include "template.helmParameters" (dict "prefix" "" "data" .Values) | indent 8 }}
    {{- include "template.helmParameters" (dict "prefix" "argo" "data" .Values.argo) | indent 8 }}
*/}}
{{- define "template.helmParameters" -}}
    {{- $ctx := . -}}
    {{- if kindIs "map" .data }}
        {{- range $key, $value := .data }}
            {{- include "template.helmParameters" (dict "prefix" (printf "%s%s" ((eq $ctx.prefix "") | ternary "" (printf "%s." $ctx.prefix)) $key) "data" $value ) }}
        {{- end }}
    {{- else if kindIs "slice" .data }}
        {{- range $index, $value := .data }}
            {{- if or (kindIs "map" $value) (kindIs "slice" $value) }}
                {{- fail "Error: Only strings and booleans are allowed in arrays when converting with template.helmParameters" }}
            {{- end }}
            {{- include "template.helmParameters" (dict "prefix" (printf "%s[%d]" $ctx.prefix $index) "data" $value ) }}
        {{- end }}
    {{- else }}
- name: {{ .prefix }}
        {{- if kindIs "string" .data }}
  value: "{{ .data }}"
  forceString: true
        {{- else if kindIs "bool" .data }}
  value: "{{ .data }}"
        {{- else }}
  value: {{ .data }}
        {{- end }}
    {{- end }}
{{- end -}}
