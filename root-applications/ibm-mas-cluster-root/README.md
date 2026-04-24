IBM MAS Cluster Root Application
===============================================================================
Manages cluster-level prerequisites, operators, and generates instance root applications for MAS deployments on a specific OpenShift cluster.

## Table of Contents

- [Configuration Files](#configuration-files)
  - [Instance ApplicationSet Configuration](#instance-applicationset-configuration)
  - [SLS ApplicationSet Configuration](#sls-applicationset-configuration)
  - [AI Service Instance ApplicationSet Configuration](#ai-service-instance-applicationset-configuration)
- [Helm Parameters](#helm-parameters)
  - [Role Configuration](#role-configuration)
  - [Repository Configuration](#repository-configuration)
  - [ArgoCD Configuration](#argocd-configuration)
  - [ArgoCD Vault Plugin Configuration](#argocd-vault-plugin-configuration)
  - [Behavior Flags](#behavior-flags)
  - [Additional Parameters](#additional-parameters)
- [Values Configuration](#values-configuration)
  - [Required Values](#required-values)
  - [Optional Values with Defaults](#optional-values-with-defaults)
  - [Optional Values (No Defaults)](#optional-values-no-defaults)
- [ArgoCD Applications](#argocd-applications)
  - [Role Conditions](#role-conditions)
- [ApplicationSet Behavior](#applicationset-behavior)
  - [Instance ApplicationSet](#instance-applicationset)
  - [SLS ApplicationSet](#sls-applicationset)
  - [AI Service Instance ApplicationSet](#ai-service-instance-applicationset)
- [Example Configuration](#example-configuration)
  - [Minimal values.yaml (for local testing)](#minimal-valuesyaml-for-local-testing)
  - [Sample Configuration File Structure](#sample-configuration-file-structure)
- [Related Documentation](#related-documentation)

<!--docs-include-start-->

This application is part of the **App of Apps** hierarchy:

```
ibm-mas-account-root
└── ibm-mas-cluster-root (this application)
    ├── ibm-mas-instance-root
    ├── ibm-mas-sls-root
    └── ibm-aiservice-instance-root
        └── ibm-aiservice-tenant-root
```

For more information about the GitOps architecture and concepts, see:
- [GitOps Architecture](https://ibm-mas.github.io/gitops/architecture/)
- [Cluster Root Application](https://ibm-mas.github.io/gitops/charts/root-applications/#cluster-root-application)
- [Configuration Repository](https://ibm-mas.github.io/gitops/configrepo/)
- [Helm Charts](https://ibm-mas.github.io/gitops/helmcharts/)

## Configuration Files

The Cluster Root Application does not use an ApplicationSet with git generators. Instead, it directly renders ArgoCD Applications and ApplicationSets based on values passed from the parent Account Root ApplicationSet.

The following ApplicationSets within this chart consume configuration files:

### Instance ApplicationSet Configuration

| Configuration File Pattern | Purpose | Required |
|---------------------------|---------|----------|
| `{account.id}/{cluster.id}/*/ibm-mas-instance-base.yaml` | **Base instance configuration** - Must be first generator. Defines core instance settings. | Yes |
| `{account.id}/{cluster.id}/*/ibm-db2u.yaml` | Db2u operator configuration | No |
| `{account.id}/{cluster.id}/*/ibm-mas-suite.yaml` | MAS Suite configuration | No |
| `{account.id}/{cluster.id}/*/ibm-sls.yaml` | Suite License Service configuration | No |
| `{account.id}/{cluster.id}/*/ibm-mas-workspaces.yaml` | MAS workspace configurations | No |
| `{account.id}/{cluster.id}/*/ibm-mas-suite-configs.yaml` | MAS suite-level configurations (JDBC, Kafka, etc.) | No |
| `{account.id}/{cluster.id}/*/ibm-db2u-databases.yaml` | Db2 database configurations | No |
| `{account.id}/{cluster.id}/*/ibm-dbs-rds-databases.yaml` | RDS database configurations | No |
| `{account.id}/{cluster.id}/*/ibm-mas-masapp-manage-install.yaml` | Manage application installation | No |
| `{account.id}/{cluster.id}/*/ibm-mas-masapp-iot-install.yaml` | IoT application installation | No |
| `{account.id}/{cluster.id}/*/ibm-mas-masapp-assist-install.yaml` | Assist application installation | No |
| `{account.id}/{cluster.id}/*/ibm-mas-masapp-facilities-install.yaml` | Facilities application installation | No |
| `{account.id}/{cluster.id}/*/ibm-mas-masapp-visualinspection-install.yaml` | Visual Inspection application installation | No |
| `{account.id}/{cluster.id}/*/ibm-mas-masapp-optimizer-install.yaml` | Optimizer application installation | No |
| `{account.id}/{cluster.id}/*/ibm-mas-masapp-monitor-install.yaml` | Monitor application installation | No |
| `{account.id}/{cluster.id}/*/ibm-mas-masapp-predict-install.yaml` | Predict application installation | No |
| `{account.id}/{cluster.id}/*/ibm-mas-masapp-health-install.yaml` | Health application installation | No |
| `{account.id}/{cluster.id}/*/ibm-mas-masapp-configs.yaml` | MAS application workspace configurations | No |
| `{account.id}/{cluster.id}/*/ibm-cp4d.yaml` | Cloud Pak for Data configuration | No |
| `{account.id}/{cluster.id}/*/ibm-cp4d-services-base.yaml` | CP4D services base configuration | No |
| `{account.id}/{cluster.id}/*/ibm-wsl.yaml` | Watson Studio Local configuration | No |
| `{account.id}/{cluster.id}/*/ibm-wml.yaml` | Watson Machine Learning configuration | No |
| `{account.id}/{cluster.id}/*/ibm-spark.yaml` | Analytics Engine (Spark) configuration | No |
| `{account.id}/{cluster.id}/*/ibm-spss.yaml` | SPSS Modeler configuration | No |

### SLS ApplicationSet Configuration

| Configuration File Pattern | Purpose | Required |
|---------------------------|---------|----------|
| `{account.id}/icn/{cluster.id}/*/ibm-sls.yaml` | Standalone SLS instance configuration | Yes |

### AI Service Instance ApplicationSet Configuration

| Configuration File Pattern | Purpose | Required |
|---------------------------|---------|----------|
| `{account.id}/{cluster.id}/*/ibm-aiservice-instance-base.yaml` | **Base AI Service configuration** - Must be first generator. | Yes |
| `{account.id}/{cluster.id}/*/ibm-mas-odh-install.yaml` | OpenDataHub installation configuration | No |
| `{account.id}/{cluster.id}/*/ibm-aiservice.yaml` | AI Service configuration | No |

**Note:** The path pattern `{account.id}/{cluster.id}/*/` means files are organized as `{account.id}/{cluster.id}/{instance.id}/filename.yaml` in the config repository.

## Helm Parameters

The following parameters are passed from the parent Account Root ApplicationSet to this application:

### Role Configuration

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| `cluster_admin_role` | Enable cluster-admin level resources (operators, CRDs, cluster-scoped resources) | `true` |
| `application_admin_role` | Enable application-admin level resources (namespace-scoped resources) | `true` |

### Repository Configuration

| Parameter | Description | Source |
|-----------|-------------|--------|
| `generator.repo_url` | Git repository URL for configuration files | Passed from account root |
| `generator.revision` | Git revision/branch for configuration files | Passed from account root |
| `source.repo_url` | Git repository URL for GitOps source code | Passed from account root |
| `source.revision` | Git revision/branch for GitOps source code | Passed from account root |

### ArgoCD Configuration

| Parameter | Description | Source |
|-----------|-------------|--------|
| `argo.namespace` | Namespace where ArgoCD is installed | Passed from account root |
| `argo.instance` | ArgoCD instance name (optional) | Passed from account root |
| `argo.projects.rootapps` | ArgoCD project for root applications | Passed from account root |
| `argo.projects.apps` | ArgoCD project for child applications | Passed from account root |

### ArgoCD Vault Plugin Configuration

| Parameter | Description | Source |
|-----------|-------------|--------|
| `avp.name` | ArgoCD Vault Plugin name | Passed from account root |
| `avp.secret` | Secret name for vault authentication | Passed from account root |
| `avp.values_varname` | Environment variable name for Helm values | Passed from account root |

### Behavior Flags

| Parameter | Description | Source |
|-----------|-------------|--------|
| `auto_delete` | Enable automatic pruning of deleted resources | Passed from account root |
| `override_dns_cis_flags_to_false` | Override DNS CIS flags to false | Passed from account root |
| `disable_docdb_instance_user_management` | Disable DocumentDB instance user management | Passed from account root |

### Additional Parameters

| Parameter | Description | Source |
|-----------|-------------|--------|
| `account.id` | Account/environment identifier | Passed from account root |
| `region.id` | Region identifier | Passed from account root |
| `cluster.id` | Cluster identifier | Passed from account root |
| `cluster.nonshared` | Cluster non-shared flag | Passed from account root |
| `devops.mongo_uri` | DevOps MongoDB URI | Passed from account root |
| `devops.build_number` | DevOps build number | Passed from account root |
| `notifications.slack_channel_id` | Slack channel for notifications | Passed from account root |
| `ibm_operator_catalog.mas_catalog_version` | MAS catalog version | Passed from account root |
| `application_admin_service_account.name` | Application admin service account name | Passed from account root |
| `application_admin_service_account.namespace` | Application admin service account namespace | Passed from account root |
| `custom_labels` | Additional custom labels | Passed from account root |

## Values Configuration

**Important:** This application receives its values from the parent Account Root ApplicationSet. The `values.yaml` file in this chart provides defaults for local development and testing only.

### Required Values

These values **must** be provided by the parent ApplicationSet:

| Value Path | Description | Example |
|------------|-------------|---------|
| `account.id` | Account/environment identifier | `dev`, `prod`, `staging` |
| `region.id` | Region identifier | `us-east-1`, `eu-west-1` |
| `cluster.id` | Cluster identifier | `cluster-east-1` |
| `generator.repo_url` | Git repository URL containing configuration files | `https://github.com/org/config-repo` |
| `generator.revision` | Git branch/tag for configuration repository | `main`, `v1.0.0` |

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
| `cluster_admin_role` | Enable cluster admin resources | `true` |
| `application_admin_role` | Enable application admin resources | `true` |

### Optional Values (No Defaults)

| Value Path | Description | Usage |
|------------|-------------|-------|
| `argo.instance` | ArgoCD instance label | Set when using multiple ArgoCD instances |
| `avp.secret` | Vault authentication secret | Required when using ArgoCD Vault Plugin |
| `custom_labels` | Additional labels for applications | Custom labeling for organization |
| `override_dns_cis_flags_to_false` | DNS CIS override flag | Set to override DNS configurations |
| `disable_docdb_instance_user_management` | DocumentDB user management flag | Set to disable user management |
| `cluster.nonshared` | Cluster non-shared flag | Set for non-shared cluster configurations |
| `devops.mongo_uri` | DevOps MongoDB URI | Internal DevOps tracking |
| `devops.build_number` | DevOps build number | Internal DevOps tracking |
| `notifications.slack_channel_id` | Slack channel ID | Enable Slack notifications |
| `ibm_operator_catalog.mas_catalog_version` | MAS catalog version | Override default catalog version |
| `application_admin_service_account.name` | Service account name | Custom service account configuration |
| `application_admin_service_account.namespace` | Service account namespace | Custom service account configuration |

## ArgoCD Applications

The following table lists all ArgoCD applications and ApplicationSets defined in the templates folder and their rendering conditions based on admin roles:

| Template File | Application Name | Cluster Admin Role | Application Admin Role | Both Roles |
|--------------|------------------|-------------------|----------------------|------------|
| [`000-efs-csi-driver.yaml`](templates/000-efs-csi-driver.yaml) | efs-csi-driver | ✓ | | |
| [`000-ibm-operator-catalog-app.yaml`](templates/000-ibm-operator-catalog-app.yaml) | operator-catalog | ✓ | | |
| [`000-image-mirroring.yaml`](templates/000-image-mirroring.yaml) | image-mirroring | ✓ | | |
| [`000-job-cleaner.yaml`](templates/000-job-cleaner.yaml) | job-cleaner | ✓ | | |
| [`010-ibm-redhat-cert-manager-app.yaml`](templates/010-ibm-redhat-cert-manager-app.yaml) | redhat-cert-manager | ✓ | | |
| [`020-ibm-cis-cert-manager.yaml`](templates/020-ibm-cis-cert-manager.yaml) | ibm-cis-cert-manager | ✓ | | |
| [`030-ibm-dro-app.yaml`](templates/030-ibm-dro-app.yaml) | dro | ✓ | | |
| [`031-ibm-dro-public.yaml`](templates/031-ibm-dro-public.yaml) | ibm-dro-public | ✓ | | |
| [`032-ibm-dro-cleanup.yaml`](templates/032-ibm-dro-cleanup.yaml) | ibm-dro-cleanup | ✓ | | |
| [`040-cis-compliance-app.yaml`](templates/040-cis-compliance-app.yaml) | cis-compliance | ✓ | | |
| [`041-cis-compliance-cleanup.yaml`](templates/041-cis-compliance-cleanup.yaml) | cis-compliance-cleanup | ✓ | | |
| [`050-nfd-operator-app.yaml`](templates/050-nfd-operator-app.yaml) | nfd | ✓ | | |
| [`051-nvidia-gpu-operator-app.yaml`](templates/051-nvidia-gpu-operator-app.yaml) | nvidia-gpu | ✓ | | |
| [`052-group-sync-operator-app.yaml`](templates/052-group-sync-operator-app.yaml) | group-sync-operator | ✓ | | |
| [`053-falcon-operator-app.yaml`](templates/053-falcon-operator-app.yaml) | falcon-operator | ✓ | | |
| [`054-cluster-logging-operator-app.yaml`](templates/054-cluster-logging-operator-app.yaml) | cluster-logging-operator | ✓ | | |
| [`055-instana-agent-operator-app.yaml`](templates/055-instana-agent-operator-app.yaml) | instana-agent-operator | ✓ | | |
| [`060-custom-sa.yaml`](templates/060-custom-sa.yaml) | custom-sa | ✓ | | |
| [`060-selenium-grid.yaml`](templates/060-selenium-grid.yaml) | selenium-grid | ✓ | | |
| [`061-ibm-rbac-app.yaml`](templates/061-ibm-rbac-app.yaml) | ibm-rbac | ✓ | | |
| [`065-sls-appset.yaml`](templates/065-sls-appset.yaml) | sls-appset (ApplicationSet) | ✓ | | |
| [`099-aiservice-instance-appset.yaml`](templates/099-aiservice-instance-appset.yaml) | aiservice-instance-appset (ApplicationSet) | | | ✓ |
| [`099-instance-appset.yaml`](templates/099-instance-appset.yaml) | instance-appset (ApplicationSet) | | | ✓ |
| [`200-cluster-promotion-app.yaml`](templates/200-cluster-promotion-app.yaml) | cluster-promotion | ✓ | | |
| [`300-mas-provisioner-app.yaml`](templates/300-mas-provisioner-app.yaml) | mas-provisioner | ✓ | | |

### Role Conditions

- **Cluster Admin Role**: Applications that require `cluster_admin_role` to be set (21 applications)
- **Both Roles**: Applications/ApplicationSets rendered regardless of role settings (2 ApplicationSets)

**Note**: Most applications have additional conditions beyond role requirements (e.g., specific values must be defined). Refer to individual template files for complete rendering logic.

## ApplicationSet Behavior

### Instance ApplicationSet

The Instance ApplicationSet ([`099-instance-appset.yaml`](templates/099-instance-appset.yaml)) generates MAS Instance Root Applications:

**Merge Strategy:**
- Uses a **merge generator** with `merge-key` to combine multiple configuration files
- The **base generator** (`ibm-mas-instance-base.yaml`) must be present and is listed first
- Additional generators merge their configurations with the base using the `merge-key` field
- All config files must include: `merge-key: "{account.id}/{cluster.id}/{instance.id}"`

**Sync Policy:**

| Setting | Value | Description |
|---------|-------|-------------|
| `applicationsSync` | `sync` (if `auto_delete=true`) or `create-update` | Controls whether deleted configs delete applications |
| `automated.prune` | `true` (if `auto_delete=true`) | Automatically delete resources when removed from Git |
| `automated.selfHeal` | `true` | Automatically sync when cluster state drifts from Git |
| `retry.limit` | `-1` | Unlimited retry attempts for failed syncs |

**Generated Application Naming:** `instance.{cluster.id}.{instance.id}`

### SLS ApplicationSet

The SLS ApplicationSet ([`065-sls-appset.yaml`](templates/065-sls-appset.yaml)) generates standalone SLS Root Applications:

**Generator:** Single git generator (no merge)
- Path: `{account.id}/icn/{cluster.id}/*/ibm-sls.yaml`

**Generated Application Naming:** `sls.root.{ibm_customer_number}.{subscription_id}`

### AI Service Instance ApplicationSet

The AI Service Instance ApplicationSet ([`099-aiservice-instance-appset.yaml`](templates/099-aiservice-instance-appset.yaml)) generates AI Service Instance Root Applications:

**Merge Strategy:**
- Uses a **merge generator** with `merge-key`
- Base generator: `ibm-aiservice-instance-base.yaml`
- All config files must include: `merge-key: "{account.id}/{cluster.id}/{instance.id}"`

**Generated Application Naming:** `aiservice-instance.{cluster.id}.{instance.id}`

## Example Configuration

### Minimal values.yaml (for local testing)

```yaml
account:
  id: "production"

region:
  id: "us-east-1"

cluster:
  id: "cluster-east-1"

generator:
  repo_url: "https://github.com/myorg/mas-config"
  revision: "main"

source:
  repo_url: "https://github.com/ibm-mas/gitops"
  revision: "main"

argo:
  namespace: "openshift-gitops"
  projects:
    rootapps: "mas"
    apps: "mas"
```

### Sample Configuration File Structure

```
config-repo/
├── production/
│   └── cluster-east-1/
│       ├── instance1/
│       │   ├── ibm-mas-instance-base.yaml      # Required for instance
│       │   ├── ibm-mas-suite.yaml              # Optional
│       │   ├── ibm-sls.yaml                    # Optional
│       │   └── ibm-db2u.yaml                   # Optional
│       ├── aiservice1/
│       │   ├── ibm-aiservice-instance-base.yaml # Required for AI Service
│       │   └── ibm-aiservice.yaml              # Optional
│       └── icn/
│           └── cluster-east-1/
│               └── sls1/
│                   └── ibm-sls.yaml            # Required for standalone SLS
```

Each configuration file must include:
```yaml
merge-key: "production/cluster-east-1/instance1"  # Format: {account.id}/{cluster.id}/{instance.id}
instance:
  id: "instance1"
# ... additional configuration
```

## Related Documentation

- [Account Root Application](../ibm-mas-account-root/README.md) - Parent application
- [Instance Root Application](../ibm-mas-instance-root/README.md) - Generated child applications
- [SLS Root Application](../ibm-mas-sls-root/README.md) - Generated SLS applications
- [AI Service Instance Root Application](../ibm-aiservice-instance-root/README.md) - Generated AI Service applications
- [Cluster Applications](../../docs/charts/cluster-applications.md) - Cluster-level resources