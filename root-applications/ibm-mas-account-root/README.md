IBM MAS Account Root Application
===============================================================================
Installs the Cluster Root ArgoCD ApplicationSet [`000-cluster-appset.yaml`](templates/000-cluster-appset.yaml) responsible for generating a set of IBM MAS Cluster Root ArgoCD Applications. See [ibm-mas-cluster-root README](../ibm-mas-cluster-root/README.md) for more details on the generated applications.

## Table of Contents

- [Configuration Files](#configuration-files)
  - [Base Configuration (Required)](#base-configuration-required)
  - [Optional Feature Configurations](#optional-feature-configurations)
- [Helm Parameters](#helm-parameters)
  - [Role Configuration](#role-configuration)
  - [Repository Configuration](#repository-configuration)
  - [ArgoCD Configuration](#argocd-configuration)
  - [ArgoCD Vault Plugin Configuration](#argocd-vault-plugin-configuration)
  - [Behavior Flags](#behavior-flags)
- [Values Configuration](#values-configuration)
  - [Required Values](#required-values)
  - [Optional Values with Defaults](#optional-values-with-defaults)
  - [Optional Values (No Defaults)](#optional-values-no-defaults)
- [ArgoCD Applications](#argocd-applications)
  - [Role Conditions](#role-conditions)
- [ApplicationSet Behavior](#applicationset-behavior)
  - [Merge Strategy](#merge-strategy)
  - [Sync Policy](#sync-policy)
  - [Generated Application Naming](#generated-application-naming)
- [Example Configuration](#example-configuration)
  - [Minimal values.yaml](#minimal-valuesyaml)
  - [Sample Configuration File Structure](#sample-configuration-file-structure)

<!--docs-include-start-->

This is the top-level application in the **App of Apps** hierarchy:

```
ibm-mas-account-root (this application)
└── ibm-mas-cluster-root
    ├── ibm-mas-instance-root
    ├── ibm-mas-sls-root
    └── ibm-aiservice-instance-root
        └── ibm-aiservice-tenant-root
```

For more information about the GitOps architecture and concepts, see:  
- [GitOps Architecture](https://ibm-mas.github.io/gitops/main/architecture/)  
- [Account Root Manifest](https://ibm-mas.github.io/gitops/main/accountrootmanifest/)  
- [Configuration Repository](https://ibm-mas.github.io/gitops/main/configrepo/)  
- [Helm Charts](https://ibm-mas.github.io/gitops/main/helmcharts/)  

## Configuration Files

The ApplicationSet uses a merge generator that consumes configuration files from the config repository. All files must include a `merge-key` field for proper merging (e.g., `merge-key: "account/cluster"`).

### Base Configuration (Required)

| Configuration File Pattern | Purpose |
|---------------------------|---------|
| `{account.id}/*/ibm-mas-cluster-base.yaml` | **Base cluster configuration** - Must be first generator. Defines core cluster settings including cluster ID, region, and base parameters. |

### Optional Feature Configurations

| Configuration File Pattern | Purpose |
|---------------------------|---------|
| `{account.id}/*/ibm-operator-catalog.yaml` | IBM Operator Catalog configuration for custom catalog sources |
| `{account.id}/*/redhat-cert-manager.yaml` | Red Hat Certificate Manager operator configuration |
| `{account.id}/*/ibm-cis-cert-manager.yaml` | IBM Cloud Internet Services certificate manager configuration |
| `{account.id}/*/ibm-dro.yaml` | IBM Data Reporter Operator configuration |
| `{account.id}/*/cis-compliance.yaml` | CIS compliance operator configuration |
| `{account.id}/*/nvidia-gpu-operator.yaml` | NVIDIA GPU operator for GPU-enabled workloads |
| `{account.id}/*/custom-sa.yaml` | Custom service account configurations |
| `{account.id}/*/cluster-promotion.yaml` | Cluster promotion and verification jobs |
| `{account.id}/*/selenium-grid.yaml` | Selenium Grid for automated testing |
| `{account.id}/*/group-sync-operator.yaml` | Group synchronization operator for LDAP/AD integration |
| `{account.id}/*/ibm-rbac.yaml` | IBM RBAC configurations |
| `{account.id}/*/falcon-operator.yaml` | CrowdStrike Falcon operator for security |
| `{account.id}/*/cluster-logging-operator.yaml` | OpenShift cluster logging operator |
| `{account.id}/*/instana-agent-operator.yaml` | Instana monitoring agent operator |
| `{account.id}/*/mas-provisioner.yaml` | IBM Internal only |
| `{account.id}/*/image-mirroring.yaml` | Image mirroring configuration for disconnected environments |
| `{account.id}/*/efs-csi-driver.yaml` | AWS EFS CSI driver for persistent storage |

**Note:** The path pattern `{account.id}/*/` means files are organized as `{account.id}/{cluster.id}/filename.yaml` in the config repository.

## Helm Parameters

The following parameters are passed to each generated cluster root application via Helm:

### Role Configuration

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| `cluster_admin_role` | Enable cluster-admin level resources (operators, CRDs, cluster-scoped resources) | `true` |
| `application_admin_role` | Enable application-admin level resources (namespace-scoped resources) | `true` |

### Repository Configuration

| Parameter | Description | Source |
|-----------|-------------|--------|
| `generator.repo_url` | Git repository URL for configuration files | `values.generator.repo_url` |
| `generator.revision` | Git revision/branch for configuration files | `values.generator.revision` |
| `source.repo_url` | Git repository URL for GitOps source code | `values.source.repo_url` |
| `source.revision` | Git revision/branch for GitOps source code | `values.source.revision` |

### ArgoCD Configuration

| Parameter | Description | Source |
|-----------|-------------|--------|
| `argo.namespace` | Namespace where ArgoCD is installed | `values.argo.namespace` |
| `argo.instance` | ArgoCD instance name (optional) | `values.argo.instance` |
| `argo.projects.rootapps` | ArgoCD project for root applications | `values.argo.projects.rootapps` |
| `argo.projects.apps` | ArgoCD project for child applications | `values.argo.projects.apps` |

### ArgoCD Vault Plugin Configuration

| Parameter | Description | Source |
|-----------|-------------|--------|
| `avp.name` | ArgoCD Vault Plugin name | `values.avp.name` |
| `avp.secret` | Secret name for vault authentication | `values.avp.secret` |
| `avp.values_varname` | Environment variable name for Helm values | `values.avp.values_varname` |

### Behavior Flags

| Parameter | Description | Source |
|-----------|-------------|--------|
| `auto_delete` | Enable automatic pruning of deleted resources | `values.auto_delete` |
| `override_dns_cis_flags_to_false` | Override DNS CIS flags to false | `values.override_dns_cis_flags_to_false` |
| `disable_docdb_instance_user_management` | Disable DocumentDB instance user management | `values.disable_docdb_instance_user_management` |

## Values Configuration

**Important:** Unlike other root applications that receive values from generator configuration files, the `ibm-mas-account-root` application values are set directly in the root application manifest (when deploying this application to ArgoCD). These values control the ApplicationSet behavior and are passed down to generated cluster root applications.

### Required Values

These values **must** be provided in the root application manifest's `values.yaml` or via Helm parameters:

| Value Path | Description | Example |
|------------|-------------|---------|
| `account.id` | Account/environment identifier used in config file paths | `dev`, `prod`, `staging` |
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

### Optional Values (No Defaults)

| Value Path | Description | Usage |
|------------|-------------|-------|
| `argo.instance` | ArgoCD instance label | Set when using multiple ArgoCD instances |
| `avp.secret` | Vault authentication secret | Required when using ArgoCD Vault Plugin |
| `custom_labels` | Additional labels for applications | Custom labeling for organization |
| `override_dns_cis_flags_to_false` | DNS CIS override flag | Set to override DNS configurations |
| `disable_docdb_instance_user_management` | DocumentDB user management flag | Set to disable user management |

## ArgoCD Applications

The following table lists all ArgoCD applications defined in the templates folder:

| Template File | Application Name | Cluster Admin Role | Application Admin Role | Both Roles |
|--------------|------------------|-------------------|----------------------|------------|
| [`000-cluster-appset.yaml`](templates/000-cluster-appset.yaml) | cluster-appset.{account.id} (ApplicationSet) | | | ✓ |

### Role Conditions

- **Cluster Admin Role**: Applications that require `cluster_admin_role` to be set
- **Application Admin Role**: Applications that require `application_admin_role` to be set
- **Both Roles**: Applications rendered regardless of role settings (no role condition or other conditions apply), but resources within that application are only rendered if the appropriate role is set.

**Note**: The ApplicationSet itself is always rendered. Role flags are passed to generated cluster root applications, which control resource rendering at the cluster level.

## ApplicationSet Behavior

### Merge Strategy

The ApplicationSet uses a **merge generator** with `merge-key` to combine multiple configuration files:
- The **base generator** (`ibm-mas-cluster-base.yaml`) must be present and is listed first
- Additional generators merge their configurations with the base using the `merge-key` field
- All config files must include: `merge-key: "{account.id}/{cluster.id}"`

### Sync Policy

| Setting | Value | Description |
|---------|-------|-------------|
| `applicationsSync` | `sync` (if `auto_delete=true`) or `create-update` | Controls whether deleted configs delete applications |
| `automated.prune` | `true` (if `auto_delete=true`) | Automatically delete resources when removed from Git |
| `automated.selfHeal` | `true` | Automatically sync when cluster state drifts from Git |
| `retry.limit` | `-1` | Unlimited retry attempts for failed syncs |

### Generated Application Naming

Each cluster configuration generates an application named: `cluster.{cluster.id}`

Where `{cluster.id}` comes from the `cluster.id` field in the configuration files.

## Example Configuration

### Minimal values.yaml

```yaml
account:
  id: "production"

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
│   ├── cluster-east-1/
│   │   ├── ibm-mas-cluster-base.yaml      # Required
│   │   ├── ibm-operator-catalog.yaml      # Optional
│   │   ├── redhat-cert-manager.yaml       # Optional
│   │   └── nvidia-gpu-operator.yaml       # Optional
│   └── cluster-west-1/
│       ├── ibm-mas-cluster-base.yaml      # Required
│       └── ibm-dro.yaml                   # Optional
```

Each configuration file must include:
```yaml
merge-key: "production/cluster-east-1"  # Format: {account.id}/{cluster.id}
cluster:
  id: "cluster-east-1"
region:
  id: "us-east-1"
# ... additional configuration
```
