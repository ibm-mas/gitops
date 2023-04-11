#!/bin/bash
# Install and setup Openshift Gitops

while [[ $# -gt 0 ]]
do
    key="$1"
    shift
    case $key in
        -a|--avp-ibm-instance-url)
        AVP_IBM_INSTANCE_URL=$1
        shift
        ;;
        -k|--ibm-api-key)
        IBMCLOUD_APIKEY=$1
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
cat <<EOF | oc apply  -f -
apiVersion: v1
kind: Secret
metadata:
  name: openshift-gitops-vault
  namespace: openshift-gitops
stringData: 
    vault.yml: |
        AVP_IBM_INSTANCE_URL: $AVP_IBM_INSTANCE_URL
        AVP_TYPE: ibmsecretsmanager
        AVP_IBM_API_KEY: $IBMCLOUD_APIKEY
EOF

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
