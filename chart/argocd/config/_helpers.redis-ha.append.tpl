{{/*
Redis HA workload DNS prefix for HAProxy backends and Sentinel (pods are {prefix}-node-N).

haproxy.config is rendered with tpl() inside the HAProxy subchart, so .Values only contains the haproxy subtree:
parent keys like redis-ha are not visible there. When redis-ha is missing, use the default dependency alias pattern
"{Release.Name}-redis-ha" (matches this chart's Chart.yaml alias). For a custom redis-ha fullnameOverride, set
haproxy.redisWorkloadFullnameOverride to the same string.
*/}}
{{- define "argo-cd.redis-ha.fullname" -}}
{{- $redisHa := (index .Values "redis-ha") -}}
{{- if and $redisHa $redisHa.enabled -}}
{{- $redisHaContext := dict "Chart" (dict "Name" "redis-ha") "Release" .Release "Values" $redisHa -}}
{{- include "common.names.fullname" $redisHaContext | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-redis-ha" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
