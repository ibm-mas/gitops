#!/bin/bash
# Install and setup MAS using gitops

while [[ $# -gt 0 ]]
do
    key="$1"
    shift
    case $key in
        -i|--mas-instance-name)
        MAS_INSTANCE_NAME=$1
        shift
        ;;
        -c|--cluster-name)
        IBMCLOUD_APOCP_CLUSTER_NAME=$1
        shift
        ;;
        -o|--org)
        GITHUB_ORG=$1
        shift
        ;;
        -r|--repo)
        GITHUB_REPO=$1
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


# deploy-cluster.sh is already run (or add it in here but make sure it doesn't cause other
# instances issues i.e. unexpected outages or upgrades)

# 1. Install SLS
SLS_VALUES=sls.values.yaml
echo "---" > $SLS_VALUES
echo mas_instance: $MAS_INSTANCE_NAME >> $SLS_VALUES
echo sls_channel: "3.x" >> $SLS_VALUES
echo image_registry: docker-na-public.artifactory.swg-devops.com/wiotp-docker-local >> $SLS_VALUES
# Set or Get from secrets-manager
echo vault__ibm_entitlement_key: "<path:ibmcloud/arbitrary/secrets/groups/eb2082a1-940e-ae58-2086-dcbf1ddb8d47#ibm_entitlement_key_docker_b64>" >> $SLS_VALUES

jinja2 --strict $TEMPLATE_DIR/template-cluster/apps/inst1.ibm-sls.yaml $SLS_VALUES > $OCP_CLUSTER_NAME/apps/$MAS_INSTANCE_NAME.ibm-sls.yaml
git add .
git commit -m "Adding $MAS_INSTANCE_NAME-ibm-sls for $OCP_CLUSTER_NAME" 
# git push -u origin main

# Wait for ArgoCD to say synced and ready

# 2. Install MAS Core

# 3. Configure MAS Core

