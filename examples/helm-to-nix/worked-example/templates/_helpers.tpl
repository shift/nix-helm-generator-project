{{- define "demo.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "demo.fullname" -}}
{{- printf "%s-%s" (include "demo.name" .) .Release.Name -}}
{{- end -}}
