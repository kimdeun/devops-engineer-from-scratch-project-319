{{- define "bulletin-board.labels" -}}
app.kubernetes.io/name: bulletin-board
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end }}
{{- define "bulletin-board.selectorLabels" -}}
app: bulletin-board
{{- end }}
