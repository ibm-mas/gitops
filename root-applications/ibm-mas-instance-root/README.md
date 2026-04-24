IBM MAS Instance Root Application
===============================================================================
Manages all resources for a specific MAS instance, including databases, dependencies, the MAS suite itself, and MAS applications.

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
  - [Feature-Specific Parameters](#feature-specific-parameters)
- [Values Configuration](#values-configuration)
  - [Required Values (from parent)](#required-values-from-parent)
  - [Optional Values with Defaults](#optional-values-with-defaults)
  - [Feature Flags](#feature-flags)
- [ArgoCD Applications](#argocd-applications)
  - [Role Conditions](#role-conditions)
  - [Application Categories](#application-categories)
- [Example Configuration](#example-configuration)
  - [Minimal Configuration Structure](#minimal-configuration-structure)
  - [Sample Base Configuration File](#sample-base-configuration-file)
  - [Sample Suite Configuration File](#sample-suite-configuration-file)
- [Related Documentation](#related-documentation)

<!--docs-include-start-->

This application is part of the **App of Apps** hierarchy:

```
ibm-mas-account-root
└── ibm-mas-cluster-root
    ├── ibm-mas-instance-root (this application)
    ├── ibm-mas-sls-root
    └── ibm-aiservice-instance-root
        └── ibm-aiservice-tenant-root
```

For more information about the GitOps architecture and concepts, see:
- [GitOps Architecture](https://ibm-mas.github.io/gitops/architecture/)
- [Instance Root Application](https://ibm-mas.github.io/gitops/charts/root-applications/#instance-root-application)
- [Configuration Repository](https://ibm-mas.github.io/gitops/configrepo/)
- [Helm Charts](https://ibm-mas.github.io/gitops/helmcharts/)

## Overview

The Instance Root Application orchestrates the deployment of a complete MAS instance by rendering ArgoCD Applications in a specific sequence to ensure dependencies are met. It does not use ApplicationSets; instead, it directly renders Applications based on configuration values passed from the parent Cluster Root ApplicationSet.

### Deployment Sequence

Applications are deployed in the following order (controlled by sync-wave annotations):

1. **000-010: Synchronization Resources** - Sync resources and jobs for prerequisites
2. **100-121: Dependencies** - SLS, Db2, CP4D, databases, and CP4D services
3. **130: MAS Suite** - Core MAS suite installation and configurations
4. **200: Workspaces** - MAS workspace creation
5. **500-550: Applications** - MAS application installations and configurations
6. **600: RBAC & Post-Sync** - RBAC setup and post-deployment validation

## Configuration

**Important:** This application receives its configuration from the parent Cluster Root ApplicationSet. Values are not read from a `values.yaml` file but are passed as Helm parameters from the ApplicationSet generator.

### Configuration Source

Configuration comes from files in the config repository that match the patterns defined in the Cluster Root's Instance ApplicationSet:
- `{account.id}/{cluster.id}/{instance.id}/ibm-mas-instance-base.yaml` (required)
- `{account.id}/{cluster.id}/{instance.id}/*.yaml` (optional features)

See the [Cluster Root README](../ibm-mas-cluster-root/README.md#instance-applicationset-configuration) for the complete list of configuration file patterns.

## Helm Parameters

The following parameters are passed from the parent Cluster Root ApplicationSet to this application:

### Identity Parameters

| Parameter | Description | Source |
|-----------|-------------|--------|
| `account.id` | Account/environment identifier | Passed from cluster root |
| `region.id` | Region identifier | Passed from cluster root |
| `cluster.id` | Cluster identifier | Passed from cluster root |
| `instance.id` | MAS instance identifier | From configuration file |
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
| `override_dns_cis_flags_to_false` | Override DNS CIS flags to false | Passed from cluster root |
| `disable_docdb_instance_user_management` | Disable DocumentDB instance user management | Passed from cluster root |
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

### Feature-Specific Parameters

Each MAS component (SLS, Suite, Db2, CP4D, applications) has its own set of configuration parameters defined in the respective configuration files. These are passed through the ArgoCD Vault Plugin as environment variables.

## Values Configuration

**Important:** The `values.yaml` file in this chart provides defaults for local development and testing only. In production, all values are provided by the parent Cluster Root ApplicationSet.

### Required Values (from parent)

| Value Path | Description | Example |
|------------|-------------|---------|
| `account.id` | Account/environment identifier | `dev`, `prod` |
| `region.id` | Region identifier | `us-east-1` |
| `cluster.id` | Cluster identifier | `cluster-east-1` |
| `instance.id` | MAS instance identifier | `inst1` |
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

### Feature Flags

| Value Path | Description | Default |
|------------|-------------|---------|
| `mas_feature_usage` | Enable feature usage reporting | `true` |
| `mas_deployment_progression` | Enable deployment progression reporting | `true` |
| `mas_usability_metrics` | Enable usability metrics reporting | `true` |
| `run_sanity_test` | Run sanity tests after deployment | `false` |

## ArgoCD Applications

The following table lists all ArgoCD applications defined in the templates folder and their rendering conditions based on admin roles:

| Template File | Application Name | Cluster Admin Role | Application Admin Role | Both Roles | Sync Wave |
|--------------|------------------|-------------------|----------------------|------------|-----------|
| [`000-ibm-sync-resources.yaml`](templates/000-ibm-sync-resources.yaml) | syncres | | | ✓ | 000 |
| [`010-ibm-sync-jobs.yaml`](templates/010-ibm-sync-jobs.yaml) | syncjobs | | | ✓ | 010 |
| [`100-ibm-sls-app.yaml`](templates/100-ibm-sls-app.yaml) | sls | | | ✓ | 100 |
| [`101-ibm-sync-jobs-cp4d.yaml`](templates/101-ibm-sync-jobs-cp4d.yaml) | syncjobs.cp4d | ✓ | | | 101 |
| [`110-ibm-cp4d-app.yaml`](templates/110-ibm-cp4d-app.yaml) | cp4d | ✓ | | | 110 |
| [`110-ibm-cp4d-operator-app.yaml`](templates/110-ibm-cp4d-operator-app.yaml) | cp4doperator | ✓ | | | 110 |
| [`110-ibm-cs-control-app.yaml`](templates/110-ibm-cs-control-app.yaml) | cscontrol | ✓ | | | 110 |
| [`110-ibm-db2u-app.yaml`](templates/110-ibm-db2u-app.yaml) | db2u | ✓ | | | 110 |
| [`120-db2-databases-app.yaml`](templates/120-db2-databases-app.yaml) | db2-db | | ✓ | | 120 |
| [`120-dbs-rds-databases-app.yaml`](templates/120-dbs-rds-databases-app.yaml) | dbs-rds-db | | | ✓ | 120 |
| [`120-ibm-spark-app.yaml`](templates/120-ibm-spark-app.yaml) | spark | ✓ | | | 120 |
| [`120-ibm-spss-app.yaml`](templates/120-ibm-spss-app.yaml) | spss | ✓ | | | 120 |
| [`120-ibm-wml-app.yaml`](templates/120-ibm-wml-app.yaml) | wml | ✓ | | | 120 |
| [`120-ibm-wsl-app.yaml`](templates/120-ibm-wsl-app.yaml) | wsl | ✓ | | | 120 |
| [`121-ibm-post-sync-job-cp4d-services.yaml`](templates/121-ibm-post-sync-job-cp4d-services.yaml) | postsyncjobs.cp4dservices | ✓ | | | 121 |
| [`130-ibm-mas-suite-app.yaml`](templates/130-ibm-mas-suite-app.yaml) | suite | | | ✓ | 130 |
| [`130-ibm-mas-suite-configs-app.yaml`](templates/130-ibm-mas-suite-configs-app.yaml) | mas_config_name | | ✓ | | 130 |
| [`200-ibm-mas-workspaces.yaml`](templates/200-ibm-mas-workspaces.yaml) | workspace | | ✓ | | 200 |
| [`500-ibm-mas-masapp-manage-install.yaml`](templates/500-ibm-mas-masapp-manage-install.yaml) | manage | | | ✓ | 500 |
| [`505-ibm-mas-masapp-facilities-install.yaml`](templates/505-ibm-mas-masapp-facilities-install.yaml) | facilities | | | ✓ | 505 |
| [`510-ibm-mas-masapp-assist-install.yaml`](templates/510-ibm-mas-masapp-assist-install.yaml) | assist | | | ✓ | 510 |
| [`510-ibm-mas-masapp-iot-install.yaml`](templates/510-ibm-mas-masapp-iot-install.yaml) | iot | | | ✓ | 510 |
| [`510-ibm-mas-masapp-visualinspection-install.yaml`](templates/510-ibm-mas-masapp-visualinspection-install.yaml) | visualinspection | | | ✓ | 510 |
| [`510-550-ibm-mas-masapp-configs.yaml`](templates/510-550-ibm-mas-masapp-configs.yaml) | masapp-config | | ✓ | | 510-550 |
| [`520-ibm-mas-masapp-health-install.yaml`](templates/520-ibm-mas-masapp-health-install.yaml) | health | | | ✓ | 520 |
| [`520-ibm-mas-masapp-monitor-install.yaml`](templates/520-ibm-mas-masapp-monitor-install.yaml) | monitor | | | ✓ | 520 |
| [`520-ibm-mas-masapp-optimizer-install.yaml`](templates/520-ibm-mas-masapp-optimizer-install.yaml) | optimizer | | | ✓ | 520 |
| [`540-ibm-mas-masapp-predict-install.yaml`](templates/540-ibm-mas-masapp-predict-install.yaml) | predict | | | ✓ | 540 |
| [`550-ibm-mas-addons-config.yaml`](templates/550-ibm-mas-addons-config.yaml) | addons | | ✓ | | 550 |
| [`600-application-admin-rbac-app.yaml`](templates/600-application-admin-rbac-app.yaml) | application-admin-rbac | | ✓ | | 600 |
| [`600-ibm-post-sync-jobs.yaml`](templates/600-ibm-post-sync-jobs.yaml) | postsyncjobs | | | ✓ | 600 |

### Role Conditions

- **Cluster Admin Role**: Applications that require `cluster_admin_role` to be set (10 applications)
- **Application Admin Role**: Applications that require `application_admin_role` to be set (6 applications)
- **Both Roles**: Applications rendered regardless of role settings (16 applications)

**Note**: Most applications have additional conditions beyond role requirements (e.g., specific configuration values must be defined). Refer to individual template files for complete rendering logic.

### Application Categories

#### Synchronization & Resource Management (000-010)
- **syncres** - Synchronizes resources and secrets from AWS Secrets Manager
- **syncjobs** - Pre-sync jobs for instance setup

#### Dependencies (100-121)
- **sls** - Suite License Service
- **syncjobs.cp4d** - CP4D pre-sync jobs
- **cp4d** - Cloud Pak for Data platform
- **cp4doperator** - CP4D operators
- **cscontrol** - Common Services control
- **db2u** - Db2 Universal operator
- **db2-db** - Db2 database instances
- **dbs-rds-db** - RDS database instances
- **spark** - Analytics Engine (Spark)
- **spss** - SPSS Modeler
- **wml** - Watson Machine Learning
- **wsl** - Watson Studio Local
- **postsyncjobs.cp4dservices** - CP4D services post-sync validation

#### MAS Core (130-200)
- **suite** - MAS Suite core platform
- **mas_config_name** - Suite configurations (JDBC, Kafka, SMTP, etc.)
- **workspace** - MAS workspaces

#### MAS Applications (500-550)
- **manage** - Maximo Manage (EAM)
- **facilities** - Maximo Facilities
- **assist** - Maximo Assist
- **iot** - Maximo IoT
- **visualinspection** - Maximo Visual Inspection
- **masapp-config** - Application workspace configurations
- **health** - Maximo Health
- **monitor** - Maximo Monitor
- **optimizer** - Maximo Optimizer
- **predict** - Maximo Predict
- **addons** - MAS add-ons configuration

#### RBAC & Post-Sync (600)
- **application-admin-rbac** - Application-level RBAC
- **postsyncjobs** - Post-deployment validation

## Example Configuration

### Minimal Configuration Structure

```
config-repo/
├── production/
│   └── cluster-east-1/
│       └── inst1/
│           ├── ibm-mas-instance-base.yaml      # Required
│           ├── ibm-mas-suite.yaml              # MAS Suite config
│           ├── ibm-sls.yaml                    # SLS config
│           ├── ibm-db2u.yaml                   # Db2 config
│           ├── ibm-mas-workspaces.yaml         # Workspaces
│           └── ibm-mas-masapp-manage-install.yaml  # Manage app
```

### Sample Base Configuration File

```yaml
# ibm-mas-instance-base.yaml
merge-key: "production/cluster-east-1/inst1"
instance:
  id: "inst1"
cluster:
  id: "cluster-east-1"
  url: "https://kubernetes.default.svc"
account:
  id: "production"
region:
  id: "us-east-1"
```

### Sample Suite Configuration File

```yaml
# ibm-mas-suite.yaml
merge-key: "production/cluster-east-1/inst1"
ibm_mas_suite:
  mas_workspace_id: "main"
  mas_domain: "apps.cluster-east-1.example.com"
  mas_channel: "8.11.x"
  ibm_entitlement_key: "<path:secret#key>"
  domain: "example.com"
  cert_manager_namespace: "cert-manager"
  dns_provider: "cis"
```

## Related Documentation

- [Cluster Root Application](../ibm-mas-cluster-root/README.md) - Parent application
- [Account Root Application](../ibm-mas-account-root/README.md) - Top-level application
- [Instance Applications](../../docs/charts/instance-applications.md) - Detailed component documentation
- [Configuration Patterns](../../docs/configuration/patterns.md) - Common configuration patterns
- [Deployment Orchestration](../../docs/orchestration.md) - Deployment sequencing details