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
        IBMCLOUD_APIKEY=$2
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
# # 4. Patch openshift-gitops with argocd-vault-plugin
echo 'Patch cluster ArgoCD'
cat <<EOF | oc apply  -f -
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: openshift-gitops
  namespace: openshift-gitops
spec:   
  repo:
    initContainers:
      - args:
          - >-
            wget -O argocd-vault-plugin
            https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v1.13.1/argocd-vault-plugin_1.13.1_linux_amd64
            && chmod +x argocd-vault-plugin && mv argocd-vault-plugin
            /custom-tools/
        command:
          - sh
          - '-c'
        env:
          - name: AVP_VERSION
            value: 1.13.1
        image: 'alpine:3.8'
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
    volumeMounts:
      - mountPath: /usr/local/bin/argocd-vault-plugin
        name: custom-tools
        subPath: argocd-vault-plugin
      - mountPath: /home/argocd
        name: vault
    volumes:
      - emptyDir: {}
        name: custom-tools
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
  configManagementPlugins: |-
    - name: argocd-vault-plugin
      generate:
        command: ["argocd-vault-plugin"]
        args: ["generate", "./", "-c", "/home/argocd/vault.yml"]  
EOF

oc wait --for=jsonpath='{.status.phase}'=Available argocd/openshift-gitops -n openshift-gitops