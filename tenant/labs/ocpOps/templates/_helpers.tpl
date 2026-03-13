{{- define "ocpOps.userName" -}}
{{- $userName := .Values.tenant.user.name | replace "@" "-" | lower }}
{{- $userName -}}
{{- end }}

{{- define "ocpOps.tenantName" -}}
{{- $tenantName := .Values.tenant.name | lower -}}
{{- $tenantName -}}
{{- end }}

{{- define "ocpOps.balanceNamespace" -}}
{{- $balanceNamespace := printf "balance-%s" (include "ocpOps.userName" .) | lower -}}
{{- $balanceNamespace -}}
{{- end }}
