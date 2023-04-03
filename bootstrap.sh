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

# 1.1 Install Operator Group
cat <<EOF | oc apply  -f -
apiVersion: apps/v1
kind: OperatorGroup
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
# 1.1 Install Subscription
cat <<EOF | oc apply  -f -
apiVersion: apps/v1
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

# 2. Create Secret Manager secret

cat <<EOF | oc apply  -f -
apiVersion: apps/v1
kind: Secret
metadata:
  name: openshift-gitops-vault
  namespace: openshift-operators
stringData: |    
    AVP_IBM_INSTANCE_URL: $AVP_IBM_INSTANCE_URL
    AVP_TYPE: ibmsecretsmanager
    AVP_IBM_API_KEY: $IBMCLOUD_APIKEY
EOF


oc get namespace openshift-gitops --wait

# 3. Create repo server SA
cat <<EOF | oc apply  -f -
apiVersion: apps/v1
kind: ServiceAccount
metadata:
  name: openshift-gitops-repo-sa
  namespace: openshift-gitops
EOF
# 4. Patch openshift-gitops with argocd-vault-plugin
cat <<EOF | oc apply  -f -
apiVersion: apps/v1
kind: ArgoC
metadata:
  name: openshift-gitops
  namespace: Subscription
spec:  
    channel: latest
    installPlanApproval: Automatic
    name: openshift-gitops-operator
    source: redhat-operators
    sourceNamespace: openshift-marketplace
EOF