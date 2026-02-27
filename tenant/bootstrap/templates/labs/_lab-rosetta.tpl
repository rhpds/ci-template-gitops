{{/*
Load labRosetta module defaults from values-lab-rosetta.yaml,
then merge with any overrides from .Values.labRosetta.
Usage: {{ include "labRosetta" . | fromYaml }}
*/}}
{{- define "labRosetta" -}}
{{- $defaults := (.Files.Get "values-lab-rosetta.yaml" | fromYaml).labRosetta | default dict -}}
{{- $overrides := .Values.labRosetta | default dict -}}
{{- mergeOverwrite $defaults $overrides | toYaml -}}
{{- end -}}
