{{/*
Name helpers, kept in one place so a rename is not chased through every template.
*/}}

{{- define "waiso.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "waiso.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "waiso.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "waiso.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "waiso.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "waiso.selector" -}}
app.kubernetes.io/name: {{ include "waiso.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "waiso.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "waiso.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "waiso.secretsName" -}}
{{- .Values.credentials.existingSecret | default (printf "%s-secrets" (include "waiso.fullname" .)) -}}
{{- end -}}

{{/*
An image reference for one component. Every tag falls back to global.imageTag,
then to the chart's appVersion. Call with (dict "ctx" $ "component" "api" "svc" .Values.api)
*/}}
{{- define "waiso.image" -}}
{{- $ctx := .ctx -}}
{{- $g := $ctx.Values.global -}}
{{- $repo := .svc.image.repository | default (printf "%s-%s" $g.imageRepository .component) -}}
{{- $tag := .svc.image.tag | default $g.imageTag | default $ctx.Chart.AppVersion -}}
{{- if $g.imageRegistry -}}
{{- printf "%s/%s:%s" $g.imageRegistry $repo $tag -}}
{{- else -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}
{{- end -}}

{{/*
The address browsers use for one service. An explicit publicUrls.<svc> wins;
with ingress enabled it is the ingress host; otherwise the localhost address a
`kubectl port-forward` gives. Call with
(dict "ctx" $ "svc" "api" "scheme" "http" "port" .Values.api.service.port)
*/}}
{{- define "waiso.publicUrl" -}}
{{- $ctx := .ctx -}}
{{- $explicit := index $ctx.Values.publicUrls .svc -}}
{{- if $explicit -}}
{{- $explicit -}}
{{- else if $ctx.Values.ingress.enabled -}}
{{- $ws := eq .scheme "ws" -}}
{{- $scheme := ternary (ternary "wss" "https" $ws) (ternary "ws" "http" $ws) $ctx.Values.ingress.tls.enabled -}}
{{- printf "%s://%s" $scheme (index $ctx.Values.ingress.hosts .svc) -}}
{{- else -}}
{{- printf "%s://localhost:%v" .scheme .port -}}
{{- end -}}
{{- end -}}

{{/*
What every Waiso process needs: where the database is, and the key that
decrypts stored secrets. Both come from Secrets, never inline in a Deployment.
*/}}
{{- define "waiso.commonEnv" -}}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgres.existingSecret | default (printf "%s-db" (include "waiso.fullname" .)) }}
      key: {{ .Values.postgres.existingSecretKey }}
- name: DB_CREDENTIALS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "waiso.secretsName" . }}
      key: {{ .Values.credentials.existingSecretKey }}
{{- end -}}

{{- define "waiso.scraperSecretEnv" -}}
- name: SCRAPER_ENGINE_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "waiso.secretsName" . }}
      key: {{ .Values.credentials.scraperSecretKey }}
{{- end -}}

{{- define "waiso.imagePullSecrets" -}}
{{- with .Values.global.imagePullSecrets }}
imagePullSecrets:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}

{{- define "waiso.scheduling" -}}
{{- with .nodeSelector }}
nodeSelector: {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .tolerations }}
tolerations: {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .affinity }}
affinity: {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
