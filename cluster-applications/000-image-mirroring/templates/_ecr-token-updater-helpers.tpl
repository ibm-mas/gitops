{{/*
ECR Token Updater Pod Template
This template defines the pod specification used by both the CronJob and the initial Job
*/}}
{{- define "ecr-token-updater.podTemplate" -}}
{{- $_cli_image_digest := "sha256:4636b74525a46ebd88cd540794e8e23143f0112ea85149f9dfc78d02704ad5a6" }}
metadata:
{{- if .Values.custom_labels }}
  labels:
{{ .Values.custom_labels | toYaml | indent 4 }}
{{- end }}
spec:
  restartPolicy: OnFailure
  serviceAccountName: "ecr-token-updater-sa"
  containers:
    - name: "ecr-token-updater"
      image: {{ .Values.cli_image_repo | default "quay.io/ibmmas/cli" }}@{{ $_cli_image_digest }}
      imagePullPolicy: IfNotPresent
      env:
        - name: REGION_ID
          value: {{ .Values.region_id }}
        - name: ECR_HOST
          value: {{ .Values.ecr_host }}
        - name: AWS_REGION
          valueFrom:
            secretKeyRef:
              name: aws
              key: aws_default_region
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws
              key: aws_access_key_id
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: aws
              key: aws_secret_access_key
      command:
        - /bin/sh
        - -c
        - |
          set -euo pipefail
          
          echo "- Get ECR Token"
          ECR_TOKEN=$(aws ecr get-login-password --region ${REGION_ID})
          ECR_AUTH="AWS:${ECR_TOKEN}"
          ECR_AUTH_B64=$(echo "${ECR_AUTH}" | base64 -w0 )

          echo "- Update .dockerconfigjson"
          # Get the current pull-secret and update .dockerconfigjson with the ECR auth
          UPDATED_DOCKERCONFIGJSON=$(
            oc get secret pull-secret  \
              -n openshift-config \
              -o json | \
              jq -r '.data[".dockerconfigjson"]' | \
              base64 -d | \
              jq '.auths["'${ECR_HOST}'"] = {"auth": "'${ECR_AUTH_B64}'"}'
          )

          echo "- Update pull-secret"
          oc set data secret/pull-secret \
            -n openshift-config \
            .dockerconfigjson="${UPDATED_DOCKERCONFIGJSON}"
{{- end -}}