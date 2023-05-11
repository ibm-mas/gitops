#!/bin/bash
# Install and setup cluster level service for MAS using gitops
# Script assumes you already have git over ssh setup and have access to the target repo

# pip3 install jinja2-cli

while [[ $# -gt 0 ]]
do
    key="$1"
    shift
    case $key in
        -c|--cluster-name)
        OCP_CLUSTER_NAME=$1
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

TEMPLATE_DIR=$PWD
CLONE_DIR=$TEMPLATE_DIR/tmp
mkdir $CLONE_DIR

echo $TEMPLATE_DIR
cd $CLONE_DIR
git clone git@github.ibm.com:$GITHUB_ORG/$GITHUB_REPO.git -b main || exit 1

cd $GITHUB_REPO

mkdir -p $OCP_CLUSTER_NAME/apps


# 1. Install Cluster using ansible-devops

# Wait for Cluster to be ready

# 2. Install Operator Catalog
CATALOG_VALUES=catalog.values.yaml
echo "---" > $CATALOG_VALUES
echo catalog_version: v8-230414-amd64 >> $CATALOG_VALUES
echo image_registry: docker-na-public.artifactory.swg-devops.com/wiotp-docker-local >> $CATALOG_VALUES
# Set or Get from secrets-manager
echo vault__ibm_entitlement_key: "<path:ibmcloud/arbitrary/secrets/groups/eb2082a1-940e-ae58-2086-dcbf1ddb8d47#ibm_entitlement_key_docker_b64>" >> $CATALOG_VALUES

jinja2 --strict $TEMPLATE_DIR/template-cluster/apps/ibm-operator-catalog.yaml $CATALOG_VALUES > $OCP_CLUSTER_NAME/apps/ibm-operator-catalog.yaml

git add .
git commit -m "Adding operator-catalog for $OCP_CLUSTER_NAME" 
# git push -u origin main

# Wait for ArgoCD to say synced and ready

# 3. Install CommonServices
cp $TEMPLATE_DIR/template-cluster/apps/ibm-common-services.yaml $OCP_CLUSTER_NAME/apps/ibm-common-services.yaml

git add .
git commit -m "Adding ibm-common-services for $OCP_CLUSTER_NAME" 
# git push -u origin main

# Wait for ArgoCD to say synced and ready

cd $TEMPLATE_DIR
# rm -rf $CLONE_DIR
