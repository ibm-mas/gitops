IBM AIService Instance Root Application
===============================================================================
Manages all resources for a specific AI Service instance, including ODH dependencies, AI Service application, and AI Service tenants.

## Table of Contents

- [Overview](#overview)
  - [Deployment Sequence](#deployment-sequence)
- [Configuration](#configuration)
  - [Configuration Source](#configuration-source)
- [Helm Parameters](#helm-parameters)
  - [Identity Parameters](#identity-parameters)
  - [Role Configuration](#role-configuration)
  - [Repository Configuration](#repository-configuration)
  - [ArgoCD Configuration](#argocd-configuration)
  - [ArgoCD Vault Plugin Configuration](#argocd-vault-plugin-configuration)
  - [Behavior Flags](#behavior-flags)
  - [Additional Parameters](#additional-parameters)
- [Values Configuration](#values-configuration)
  - [Required Values (from parent)](#required-values-from-parent)
  - [Optional Values with Defaults](#optional-values-with-defaults)
- [ArgoCD Applications](#argocd-applications)
  - [Role Conditions](#role-conditions)
  - [Application Categories](#application-categories)
- [Example Configuration](#example-configuration)
  - [Minimal Configuration Structure](#minimal-configuration-structure)
  - [Sample Base Configuration File](#sample-base-configuration-file)
  - [Sample AI Service Configuration File](#sample-ai-service-configuration-file)
- [Related Documentation](#related-documentation)

<!--docs-include-start-->

This application is part of the **App of Apps** hierarchy:

```
ibm-mas-account-root
└── ibm-mas-cluster-root
    ├── ibm-mas-instance-root
    ├── ibm-mas-sls-root
    └── ibm-aiservice-instance-root (this application)
        └── ibm-aiservice-tenant-root
```

For more information about the GitOps architecture and concepts, see:
- [GitOps Architecture](https://ibm-mas.github.io/gitops/architecture/)
- [AI Service Instance Root Application](https://ibm-mas.github.io/gitops/charts/root-applications/#ai-service-instance-root-application)
- [Configuration Repository](https://ibm-mas.github.io/gitops/configrepo/)
- [Helm Charts](https://ibm-mas.github.io/gitops/helmcharts/)

## Overview

The AI Service Instance Root Application orchestrates the deployment of a complete AI Service instance by rendering ArgoCD Applications in a specific sequence to ensure dependencies are met. It also generates AI Service Tenant Root Applications via ApplicationSet.

### Deployment Sequence

Applications are deployed in the following order (controlled by sync-wave annotations):

1. **030: ODH** - OpenDataHub platform installation
2. **040: AI Service** - AI Service application deployment
3. **070: Tenant ApplicationSet** - Generates AI Service Tenant Root ApplicationSet

## Configuration

**Important:** This application receives its configuration from the parent Cluster Root ApplicationSet. Values are not read from a `values.yaml` file but are passed as Helm parameters from the ApplicationSet generator.

## Configuration Files

Configuration comes from files in the config repository that match the patterns defined in the Cluster Root's AI Service Instance ApplicationSet:

| File Pattern | Required | Purpose |
|--------------|----------|---------|
| `{account.id}/{cluster.id}/{aiservice_instance_id}/ibm-aiservice-instance-base.yaml` | Yes | Base instance configuration (identity, region, cluster) |
| `{account.id}/{cluster.id}/{aiservice_instance_id}/ibm-odh.yaml` | Yes | OpenDataHub configuration |
| `{account.id}/{cluster.id}/{aiservice_instance_id}/ibm-aiservice.yaml` | Yes | AI Service application configuration |
| `{account.id}/{cluster.id}/{aiservice_instance_id}/tenants/{tenant_id}/aiservice-tenant-params.yaml` | No | Tenant-specific configurations (processed by Tenant ApplicationSet) |

See the [Cluster Root README](../ibm-mas-cluster-root/README.md) for the complete list of configuration file patterns.

## Helm Parameters

The following parameters are passed from the parent Cluster Root ApplicationSet to this application:

### Identity Parameters

| Parameter | Description | Source |
|-----------|-------------|--------|
| `account.id` | Account/environment identifier | Passed from cluster root |
| `region.id` | Region identifier | Passed from cluster root |
| `cluster.id` | Cluster identifier | Passed from cluster root |
| `aiservice_instance_id` | AI Service instance identifier | From configuration file |
| `cluster.url` | Kubernetes API server URL | Default: `https://kubernetes.default.svc` |

### Role Configuration

| Parameter | Description | Source |
|-----------|-------------|--------|
| `cluster_admin_role` | Enable cluster-admin level resources | Passed from cluster root |
| `application_admin_role` | Enable application-admin level resources | Passed from cluster root |

### Repository Configuration

| Parameter | Description | Source |
|-----------|-------------|--------|
| `generator.repo_url` | Git repository URL for configuration files | Passed from cluster root |
| `generator.revision` | Git revision/branch for configuration files | Passed from cluster root |
| `source.repo_url` | Git repository URL for GitOps source code | Passed from cluster root |
| `source.revision` | Git revision/branch for GitOps source code | Passed from cluster root |

### ArgoCD Configuration

| Parameter | Description | Source |
|-----------|-------------|--------|
| `argo.namespace` | Namespace where ArgoCD is installed | Passed from cluster root |
| `argo.instance` | ArgoCD instance name (optional) | Passed from cluster root |
| `argo.projects.rootapps` | ArgoCD project for root applications | Passed from cluster root |
| `argo.projects.apps` | ArgoCD project for child applications | Passed from cluster root |

### ArgoCD Vault Plugin Configuration

| Parameter | Description | Source |
|-----------|-------------|--------|
| `avp.name` | ArgoCD Vault Plugin name | Passed from cluster root |
| `avp.secret` | Secret name for vault authentication | Passed from cluster root |
| `avp.values_varname` | Environment variable name for Helm values | Passed from cluster root |

### Behavior Flags

| Parameter | Description | Source |
|-----------|-------------|--------|
| `auto_delete` | Enable automatic pruning of deleted resources | Passed from cluster root |
| `cluster.nonshared` | Cluster non-shared flag | Passed from cluster root |

### Additional Parameters

| Parameter | Description | Source |
|-----------|-------------|--------|
| `sm.aws_access_key_id` | AWS Secrets Manager access key ID | From configuration |
| `sm.aws_secret_access_key` | AWS Secrets Manager secret access key | From configuration |
| `devops.mongo_uri` | DevOps MongoDB URI | Passed from cluster root |
| `devops.build_number` | DevOps build number | Passed from cluster root |
| `notifications.slack_channel_id` | Slack channel for notifications | Passed from cluster root |
| `mas_catalog_version` | MAS catalog version | Passed from cluster root |
| `application_admin_service_account.name` | Application admin service account name | Passed from cluster root |
| `application_admin_service_account.namespace` | Application admin service account namespace | Passed from cluster root |
| `custom_labels` | Additional custom labels | Passed from cluster root |
| `cli_image_repo` | CLI image repository | From configuration |

## Values Configuration

**Important:** The `values.yaml` file in this chart provides defaults for local development and testing only. In production, all values are provided by the parent Cluster Root ApplicationSet.

### Required Values (from parent)

| Value Path | Description | Example |
|------------|-------------|---------|
| `account.id` | Account/environment identifier | `dev`, `prod` |
| `region.id` | Region identifier | `us-east-1` |
| `cluster.id` | Cluster identifier | `cluster-east-1` |
| `aiservice_instance_id` | AI Service instance identifier | `aiservice-inst-1` |
| `generator.repo_url` | Configuration repository URL | `https://github.com/org/config` |
| `generator.revision` | Configuration repository revision | `main` |

### Optional Values with Defaults

| Value Path | Description | Default |
|------------|-------------|---------|
| `source.repo_url` | GitOps source repository URL | `https://github.com/ibm-mas/gitops` |
| `source.revision` | GitOps source repository revision | `poc` |
| `argo.namespace` | ArgoCD namespace | `openshift-gitops` |
| `argo.projects.rootapps` | ArgoCD project for root apps | `mas` |
| `argo.projects.apps` | ArgoCD project for child apps | `mas` |
| `avp.name` | Vault plugin name | `argocd-vault-plugin-helm` |
| `avp.values_varname` | Vault values variable name | `HELM_VALUES` |
| `auto_delete` | Enable auto-pruning | `false` |
| `cluster.url` | Kubernetes API URL | `https://kubernetes.default.svc` |

## ArgoCD Applications

The following table lists all ArgoCD applications defined in the templates folder and their rendering conditions based on admin roles:

| Template File | Application Name | Cluster Admin Role | Application Admin Role | Both Roles |
|--------------|------------------|-------------------|----------------------|------------|
| [`010-ibm-db2u-app.yaml`](templates/010-ibm-db2u-app.yaml) | db2u | - | - | ✓ |
| [`020-ibm-db2u-database-app.yaml`](templates/020-ibm-db2u-database-app.yaml) | db2u-database | - | - | ✓ |
| [`030-ibm-odh-app.yaml`](templates/030-ibm-odh-app.yaml) | odh | - | - | ✓ |
| [`031-ibm-rhoai-app.yaml`](templates/031-ibm-rhoai-app.yaml) | rhoai | - | - | ✓ |
| [`040-ibm-aiservice-app.yaml`](templates/040-ibm-aiservice-app.yaml) | aiservice | - | - | ✓ |
| [`070-aiservice-tenant-appset.yaml`](templates/070-aiservice-tenant-appset.yaml) | ai-tenant-appset (ApplicationSet) | - | - | ✓ |

### Role Conditions

- **Cluster Admin Role**: Applications that require `cluster_admin_role` to be set (0 applications)
- **Application Admin Role**: Applications that require `application_admin_role` to be set (0 applications)
- **Both Roles**: Applications rendered regardless of role settings (6 applications)

**Note**: Some applications have additional conditions beyond role requirements (e.g., specific configuration values must be defined). Refer to individual template files for complete rendering logic.

### Application Categories

#### Dependencies (030)
- **odh** - OpenDataHub platform

#### AI Service (040)
- **aiservice** - AI Service application deployment

#### Tenant Management (070)
- **ai-tenant-appset** - ApplicationSet that generates AI Service Tenant Root Applications

## Examples

### Minimal Configuration Structure

```
config-repo/
├── production/
│   └── cluster-west-2/
│       └── aiservice-inst-1/
│           ├── ibm-aiservice-instance-base.yaml  # Required
│           ├── ibm-odh.yaml                      # ODH config
│           ├── ibm-aiservice.yaml                # AI Service config
│           └── tenants/
│               ├── tenant-01/
│               │   └── aiservice-tenant-params.yaml
│               └── tenant-02/
│                   └── aiservice-tenant-params.yaml
```

See the [AI Service Chart](../../instance-applications/113-ibm-aiservice/README.md) for detailed AI Service configuration examples.

## Prerequisites

- IBM Operator Catalog installed
- Cluster Root Application deployed
- Sufficient cluster resources for AI workloads
- Configuration repository with AI Service instance files
- S3-compatible object storage

## Troubleshooting

### ApplicationSet Not Generating Tenant Applications

Check the ApplicationSet status:
```bash
oc get applicationset -n openshift-gitops
oc describe applicationset ai-tenant-appset -n openshift-gitops
```

### ODH Installation Issues

Check ODH operator status:
```bash
oc get subscription -n openshift-operators | grep odh
oc get csv -n openshift-operators | grep odh
```

### AI Service Application Not Syncing

Check the AI Service application:
```bash
oc get application aiservice -n openshift-gitops
oc describe application aiservice -n openshift-gitops
```

## Related Documentation

- [Cluster Root Application](../ibm-mas-cluster-root/README.md) - Parent application
- [AI Service Tenant Root Application](../ibm-aiservice-tenant-root/README.md) - Child tenant applicationSet
- [AI Service Chart](../../instance-applications/113-ibm-aiservice/README.md) - AI Service component
- [AI Service Tenant Chart](../../instance-applications/115-ibm-aiservice-tenant/README.md) - Tenant component
- [Configuration Repository](../../docs/configrepo.md) - Configuration patterns
- [Deployment Orchestration](../../docs/orchestration.md) - Deployment sequencing details