{{- define "instana-agent.configuration_yaml" -}}
com.instana.plugin.mongodb:
  enabled: false
com.instana.ignore:
  arguments:
    - io.strimzi.operator.cluster.Main
    - kafka.Kafka
    - org.apache.zookeeper.server.quorum.QuorumPeerMain
    - io.strimzi.operator.topic.Main
    - io.strimzi.operator.user.Main
  processes:
    - stunnel
{{- if .Values.argocd_plugin_enabled }}
com.instana.plugin.argocd:
  enabled: true
  poll_rate: 10
  url: {{ .Values.argocd_server_url }}
  username:
    configuration_from:
      type: file
      file_path: /mnt/secrets/argocdUsername
  password:
    configuration_from:
      type: file
      file_path: /mnt/secrets/argocdPassword
  clusters:
{{ .Values.argocd_clusters | toYaml | indent 4 }}
{{- end }}
{{- end }}
