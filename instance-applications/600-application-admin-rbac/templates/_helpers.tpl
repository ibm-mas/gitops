{{/*
Expand the name of the chart.
*/}}
{{- define "application-admin-rbac.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "application-admin-rbac.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "application-admin-rbac.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "application-admin-rbac.labels" -}}
helm.sh/chart: {{ include "application-admin-rbac.chart" . }}
{{ include "application-admin-rbac.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.custom_labels }}
{{ toYaml .Values.custom_labels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "application-admin-rbac.selectorLabels" -}}
app.kubernetes.io/name: {{ include "application-admin-rbac.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get service account name
Defaults to {argo_namespace}-argocd-application-controller if not specified
*/}}
{{- define "application-admin-rbac.serviceAccountName" -}}
{{- if .Values.service_account.name }}
{{- .Values.service_account.name }}
{{- else }}
{{- printf "%s-argocd-application-controller" .Values.argo_namespace }}
{{- end }}
{{- end }}

{{/*
Get service account namespace
Defaults to argo_namespace if not specified
*/}}
{{- define "application-admin-rbac.serviceAccountNamespace" -}}
{{- if .Values.service_account.namespace }}
{{- .Values.service_account.namespace }}
{{- else }}
{{- .Values.argo_namespace }}
{{- end }}
{{- end }}

{{/*
Generate list of potential namespaces for this instance
*/}}
{{- define "application-admin-rbac.potentialNamespaces" -}}
{{- $inst := .Values.instance_id }}
{{- $namespaces := list }}
{{- range .Values.namespace_patterns }}
{{- $ns := . | replace "{inst}" $inst }}
{{- $namespaces = append $namespaces $ns }}
{{- end }}
{{- $namespaces | toJson }}
{{- end }}

{{/*
Generate unique ClusterRole name for this instance
*/}}
{{- define "application-admin-rbac.clusterRoleName" -}}
{{- printf "mas-application-admin-readonly-%s" .Values.instance_id }}
{{- end }}

{{/*
Generate unique ClusterRoleBinding name for this instance
*/}}
{{- define "application-admin-rbac.clusterRoleBindingName" -}}
{{- $sa := include "application-admin-rbac.serviceAccountName" . }}
{{- printf "mas-application-admin-readonly-%s-%s" $sa .Values.instance_id }}
{{- end }}