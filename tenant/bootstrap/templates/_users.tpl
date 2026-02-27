{{/*
  userList — builds a combined JSON array of all tenant usernames.

  Both sources are additive (not mutually exclusive):
    1. prefix+count:  tenant.user.prefix + tenant.user.count
       e.g. prefix=user, count=3  →  ["user1","user2","user3"]
    2. named users:   tenant.user.names (list or comma-separated string)
       e.g. names=[alice,bob]     →  ["alice","bob"]

  Combined example:
    count=2, prefix=user, names=[alice,bob]  →  ["user1","user2","alice","bob"]

  If both count=0 and names is empty, returns an empty JSON array [].

  Values consumed:
    .Values.tenant.user.count   — number of prefix-numbered users (default 0)
    .Values.tenant.user.prefix  — prefix for numbered users (e.g. "user")
    .Values.tenant.user.names   — explicit usernames, either:
                                   - a YAML list: [alice, bob]
                                   - a comma-separated string: "alice,bob"
                                     (string form is for deployer --set compatibility)

  Usage:
    {{- range $user := include "userList" . | fromJsonArray }}
      - user: {{ $user }}
    {{- end }}
*/}}
{{- define "userList" -}}
{{- $users := list -}}
{{/* Step 1: Generate prefix+count users (user1, user2, ..., userN) */}}
{{- $count := int (.Values.tenant.user.count | default 0) -}}
{{- range $i := until $count -}}
{{- $users = append $users (printf "%s%d" $.Values.tenant.user.prefix (add $i 1)) -}}
{{- end -}}
{{/* Step 2: Append explicitly named users */}}
{{- if .Values.tenant.user.names -}}
{{- if kindIs "slice" .Values.tenant.user.names -}}
{{/* names is a YAML list — append each entry */}}
{{- range $name := .Values.tenant.user.names -}}
{{- $users = append $users $name -}}
{{- end -}}
{{- else -}}
{{/* names is a string (e.g. from --set) — split on commas */}}
{{- range $name := splitList "," .Values.tenant.user.names -}}
{{- $users = append $users $name -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{/* Output as JSON array for fromJsonArray consumption */}}
{{- $users | toJson -}}
{{- end -}}
