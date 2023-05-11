#!/bin/bash
# Install and setup Openshift Gitops

while [[ $# -gt 0 ]]
do
    key="$1"
    shift
    case $key in
        -i|--avp-ibm-instance-url)
        AVP_INSTANCE_URL=$1
        shift
        ;;
        -r|--avp-aws-secret-region)
        AVP_AWS_SECRET_REGION=$1
        shift
        ;;
        -s|--avp-aws-secret-key)
        AVP_AWS_SECRET_KEY=$1
        shift
        ;;
        -a|--avp-aws-access-key)
        AVP_AWS_ACCESS_KEY=$1
        shift
        ;;
        -b|--avp-ibm-api-key)
        AVP_IBM_APIKEY=$1
        shift
        ;;
        -t|--secret-manager-type)
        AVP_TYPE=$1
        shift
        ;;        
        -p|--github-pat)
        APP_WATCHER_REPO_PAT=$1
        shift
        ;;
        -u|--github-url)
        APP_WATCHER_REPO_URL=$1
        shift
        ;;        
        *)
        # unknown option
        echo -e "\n${COLOR_RED}Usage Error: Unsupported flag \"${key}\" ${COLOR_OFF}\n\n"
        showHelp
        exit 1
        ;;
    esac
done

## Creates ArgoCD Application to watch the Environment representation Applications
if [ -z $AVP_TYPE ]
then
  echo "Missing --secret-manager-type, try run the command again passing -t ibm | aws"
  exit 1
fi
if [ $AVP_TYPE == 'aws' ]
then
  if [ -z $AVP_AWS_SECRET_REGION ] || [ -z $AVP_AWS_SECRET_REGION ] || [ -z $AVP_AWS_SECRET_REGION ]; then
    echo 'Missing required params for AWS secret manager, make sure to provide --avp-aws-secret-region, --avp-aws-secret-key and --avp-aws-access-key'
    exit 1
  fi
fi
if [ $AVP_TYPE == 'ibm' ]
then
  if [ -z $AVP_INSTANCE_URL ] || [ -z $AVP_IBM_APIKEY ]; then
    echo 'Missing required params for AWS secret manager, make sure to provide --avp-ibm-api-key and --avp-ibm-instance-url'
    exit 1
  fi
fi
# 1. Install Openshift GitOps Operator

# 1.1 Install Subscription
echo 'Deploy Openshift GitOps Operator'
cat <<EOF | oc apply  -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops
  namespace: openshift-operators
spec:  
    channel: latest
    installPlanApproval: Automatic
    name: openshift-gitops-operator
    source: redhat-operators
    sourceNamespace: openshift-marketplace
EOF
sleep 60
oc wait --for=condition=Established crd/argocds.argoproj.io


# # 2. Create Secret Manager secret
echo 'Create Secret Manager Backend Secret'
if [ $AVP_TYPE == 'aws' ]
then
  cat <<EOF | oc apply  -f -
apiVersion: v1
kind: Secret
metadata:
  name: openshift-gitops-vault
  namespace: openshift-gitops
stringData: 
    vault.yml: |
        AVP_TYPE: awssecretsmanager
        AWS_REGION: $AVP_AWS_SECRET_REGION
        AWS_ACCESS_KEY_ID: $AVP_AWS_ACCESS_KEY
        AWS_SECRET_ACCESS_KEY: $AVP_AWS_SECRET_KEY
EOF
else
cat <<EOF | oc apply  -f -
apiVersion: v1
kind: Secret
metadata:
  name: openshift-gitops-vault
  namespace: openshift-gitops
stringData: 
    vault.yml: |
        AVP_IBM_INSTANCE_URL: $AVP_INSTANCE_URL
        AVP_TYPE: ibmsecretsmanager
        AVP_IBM_API_KEY: $IBMCLOUD_APIKEY
EOF
fi

# 3. Create repo server SA
echo 'Create ArgoCD repo server service account'
cat <<EOF | oc apply  -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openshift-gitops-repo-sa
  namespace: openshift-gitops  
EOF
cat <<EOF | oc apply  -f -
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: openshift-gitops
  namespace: openshift-gitops
subjects:
  - kind: ServiceAccount
    name: openshift-gitops-repo-sa
    namespace: openshift-gitops
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
EOF
# 4. Create ConfigPluginManagement
cat <<EOF | oc apply  -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: cmp-plugin
  namespace: openshift-gitops
  uid: e0018fec-24ab-4ffd-9d30-fd4333ced6f9
  resourceVersion: '3408154'
  creationTimestamp: '2023-04-06T16:05:57Z'
  managedFields:
    - manager: Mozilla
      operation: Update
      apiVersion: v1
      time: '2023-04-06T16:05:57Z'
      fieldsType: FieldsV1
      fieldsV1:
        'f:data':
          .: {}
          'f:avp.yaml': {}
data:
  avp.yaml: |
    apiVersion: argoproj.io/v1alpha1
    kind: ConfigManagementPlugin
    metadata:
      name: argocd-vault-plugin-helm
    spec:
      allowConcurrency: true
      discover:
        find:
          command:
            - sh
            - "-c"
            - "find . -name 'Chart.yaml' && find . -name 'values.yaml'"
      generate:        
        command:
        - bash
        - "-c"
        - |
          helm template \$ARGOCD_APP_NAME -n \$ARGOCD_APP_NAMESPACE -f <(echo "\$ARGOCD_ENV_HELM_VALUES") . |
          argocd-vault-plugin generate -c /home/argocd/vault.yml - 
      lockRepo: false
EOF

# # 4. Patch openshift-gitops with argocd-vault-plugin
echo 'Patch cluster ArgoCD'
cat <<EOF | oc apply  -f -
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: openshift-gitops
  namespace: openshift-gitops
spec:
  resourceTrackingMethod: annotation+label
  server:
    autoscale:
      enabled: false
    grpc:
      ingress:
        enabled: false
    ingress:
      enabled: false
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 125m
        memory: 128Mi
    route:
      enabled: true
    service:
      type: ''
  grafana:
    enabled: false
    ingress:
      enabled: false
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 250m
        memory: 128Mi
    route:
      enabled: false
  monitoring:
    enabled: false
  notifications:
    enabled: false
  prometheus:
    enabled: false
    ingress:
      enabled: false
    route:
      enabled: false
  initialSSHKnownHosts: {}
  sso:
    dex:
      openShiftOAuth: true
      resources:
        limits:
          cpu: 500m
          memory: 256Mi
        requests:
          cpu: 250m
          memory: 128Mi
    provider: dex
  applicationSet:
    resources:
      limits:
        cpu: '2'
        memory: 1Gi
      requests:
        cpu: 250m
        memory: 512Mi
    webhookServer:
      ingress:
        enabled: false
      route:
        enabled: false
  rbac:
    policy: |
      g, system:cluster-admins, role:admin
      g, cluster-admins, role:admin
    scopes: '[groups]'
  repo:
    initContainers:
      - args:
          - >-
            curl -L
            https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v\$(AVP_VERSION)/argocd-vault-plugin_\$(AVP_VERSION)_linux_amd64
            -o argocd-vault-plugin && chmod +x argocd-vault-plugin && mv
            argocd-vault-plugin /custom-tools/
        command:
          - sh
          - '-c'
        env:
          - name: AVP_VERSION
            value: 1.11.0
        image: registry.access.redhat.com/ubi8
        name: download-tools
        resources: {}
        volumeMounts:
          - mountPath: /custom-tools
            name: custom-tools
    mountsatoken: true
    resources:
      limits:
        cpu: '1'
        memory: 1Gi
      requests:
        cpu: 250m
        memory: 256Mi
    serviceaccount: openshift-gitops-repo-sa
    sidecarContainers:
      - command:
          - /var/run/argocd/argocd-cmp-server
        image: 'quay.io/ibmmas/cli:3.18.1-pre.gitops'
        imagePullPolicy: Always
        name: avp
        resources: {}
        securityContext:
          runAsNonRoot: true
          runAsUser: 999
        volumeMounts:
          - mountPath: /var/run/argocd
            name: var-files
          - mountPath: /home/argocd/cmp-server/plugins
            name: plugins
          - mountPath: /tmp
            name: tmp
          - mountPath: /home/argocd/cmp-server/config/plugin.yaml
            name: cmp-plugin
            subPath: avp.yaml
          - mountPath: /usr/local/bin/argocd-vault-plugin
            name: custom-tools
            subPath: argocd-vault-plugin
          - mountPath: /home/argocd/vault.yml
            name: vault
            subPath: vault.yml
    volumeMounts:
      - mountPath: /usr/local/bin/argocd-vault-plugin
        name: custom-tools
        subPath: argocd-vault-plugin
      - mountPath: /home/argocd
        name: vault
    volumes:
      - emptyDir: {}
        name: custom-tools
      - configMap:
          name: cmp-plugin
        name: cmp-plugin
      - name: vault
        secret:
          secretName: openshift-gitops-vault
  resourceExclusions: |
    - apiGroups:
      - tekton.dev
      clusters:
      - '*'
      kinds:
      - TaskRun
      - PipelineRun
    - apiGroups:
      - cert-manager.io
      clusters:
      - '*'
      kinds:
      - Certificate
      - ClusterIssuer
      - Issuer  
  ha:
    enabled: false
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 250m
        memory: 128Mi
  tls:
    ca: {}
  redis:
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 250m
        memory: 128Mi
  controller:
    processors: {}
    resources:
      limits:
        cpu: '2'
        memory: 2Gi
      requests:
        cpu: 250m
        memory: 1Gi
    sharding: {}
EOF

oc wait --for=jsonpath='{.status.phase}'=Available argocd/openshift-gitops -n openshift-gitops

if [-z $APP_WATCHER_REPO_URL] || [-z $APP_WATCHER_REPO_PAT]; then
  echo 'No Environment watcher github repository provided, make sure to provide --github-pat and --github-url'
  exit 1
else
  echo 'Creates repository secret and environment watcher ArgoCD Application'
  cat <<EOF | oc apply  -f -
---
kind: Secret
apiVersion: v1
metadata:
  name: ghe-pat-secret
  namespace: openshift-gitops
stringData:
  password: $APP_WATCHER_REPO_PAT
  url: $APP_WATCHER_REPO_URL
  username: not-used
type: Opaque
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: environment-watcher
  namespace: openshift-gitops
spec:
  destination:
    server: 'https://kubernetes.default.svc'
  source:
    path: .
    repoURL: $APP_WATCHER_REPO_URL
    targetRevision: HEAD
    directory:
      recurse: true
  sources: []
  project: default
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
EOF
fi