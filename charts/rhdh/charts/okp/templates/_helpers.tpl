{{/*
Return the OKP deployment/service/route/ingress name.
Mirrors rhdh.lightspeed.okp.fullname from rhdh-chart.
*/}}
{{- define "okp.fullname" -}}
{{- printf "%s-lightspeed-okp" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return OKP labels. Mirrors rhdh.lightspeed.okp.labels.
*/}}
{{- define "okp.labels" -}}
app.kubernetes.io/name: lightspeed-okp
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: lightspeed-okp
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Return OKP selector labels. Mirrors rhdh.lightspeed.okp.selectorLabels.
*/}}
{{- define "okp.selectorLabels" -}}
app.kubernetes.io/name: lightspeed-okp
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
