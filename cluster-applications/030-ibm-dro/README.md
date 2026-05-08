IBM DRO
===============================================================================
Deploy and configure DRO (Data Reporter Operator).

<!--docs-include-start-->


The `dro_cmm_setup` being set to true is used to configure connectivity to CMM which is an internal IBM tool, and is not required outside of IBM.

## Configuration

### Values

```yaml
ibm_dro:
  # DRO namespace
  # Namespace where DRO operators will be installed
  # Default: ibm-software-central
  dro_namespace: "ibm-software-central"

  # IBM Entitlement Key (required)
  # Your IBM entitlement key for accessing IBM container images
  ibm_entitlement_key: ""

  # Enable sync hooks for post-deployment tasks
  # When true, creates Jobs to update AWS Secrets Manager
  # Default: true
  run_sync_hooks: true

  # CMM setup (IBM internal only)
  # Enable connectivity to CMM (Centralized Metering and Monitoring)
  # Set to false for non-IBM deployments
  # Default: false
  dro_cmm_setup: false

  # DRO operator install plan approval
  # Options: "Automatic" or "Manual"
  # Default: Automatic
  dro_install_plan: Automatic

  # IBM Metrics Operator install plan approval
  # Options: "Automatic" or "Manual"
  # Default: Automatic
  imo_install_plan: Automatic

  # Public domain configuration (optional)
  # Required for exposing DRO publicly with custom domain
  dro_public_domain: ""

  # TLS certificate for public domain (optional, base64 encoded)
  # Required when dro_public_domain is set
  tls_certificate: ""

  # TLS private key for public domain (optional, base64 encoded)
  # Required when dro_public_domain is set
  tls_key: ""

  # IBM CIS CRN (optional)
  # Cloud Internet Services CRN for DNS management
  # Required when dro_public_domain is set
  cis_crn: ""

  # CMM configuration (IBM internal only, optional)
  # Only used when dro_cmm_setup is true
  dro_cmm:
    # CMM authentication API key
    auth_apikey: ""
    
    # CMM authentication URL
    auth_url: ""
    
    # CMM service URL
    cmm_url: ""
```

## Base Cluster Values

This chart inherits common cluster configuration values. The most frequently used base values are:

```yaml
account:
  id: string                    # AWS account identifier

region:
  id: string                    # AWS region identifier

cluster:
  id: string                    # Unique cluster identifier
  url: string                   # OpenShift cluster API URL
  nonshared: boolean            # Whether cluster is dedicated (true) or shared (false)

sm:                             # Secrets Manager configuration
  aws_access_key_id: string (secret reference)
  aws_secret_access_key: string (secret reference)
```

For complete documentation of all base cluster values including optional fields like `notifications`, `custom_labels`, `devops`, and `cli_image_repo`, see the [Cluster Base Values Reference](../../docs/reference/cluster-base-values.md).

### Usage Examples

**Basic DRO installation:**
```yaml
ibm_dro:
  dro_namespace: "ibm-software-central"
  ibm_entitlement_key: "your-entitlement-key"
  run_sync_hooks: true
  dro_cmm_setup: false
  dro_install_plan: Automatic
  imo_install_plan: Automatic
```

**With public domain and TLS:**
```yaml
ibm_dro:
  dro_namespace: "ibm-software-central"
  ibm_entitlement_key: "your-entitlement-key"
  run_sync_hooks: true
  dro_cmm_setup: false
  dro_install_plan: Automatic
  imo_install_plan: Automatic
  dro_public_domain: "dro.example.com"
  tls_certificate: "LS0tLS1CRUdJTi..." # base64 encoded cert
  tls_key: "LS0tLS1CRUdJTi..." # base64 encoded key
  cis_crn: "crn:v1:bluemix:public:internet-svcs:..."
```

**With manual install plan approval:**
```yaml
ibm_dro:
  dro_namespace: "ibm-software-central"
  ibm_entitlement_key: "your-entitlement-key"
  run_sync_hooks: true
  dro_cmm_setup: false
  dro_install_plan: Manual
  imo_install_plan: Manual
```

**IBM internal with CMM (IBM only):**
```yaml
ibm_dro:
  dro_namespace: "ibm-software-central"
  ibm_entitlement_key: "your-entitlement-key"
  run_sync_hooks: true
  dro_cmm_setup: true
  dro_install_plan: Automatic
  imo_install_plan: Automatic
  dro_cmm:
    auth_apikey: "cmm-api-key"
  auth_url: "https://cmm-auth.example.com"
  cmm_url: "https://cmm.example.com"
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `ibm-mas-operator-group` | `ibm-software-central` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Secret` | `redhat-marketplace-pull-secret` | `ibm-software-central` | When `application_admin_role` is true | `application_admin_role` |
| `Subscription` | `ibm-metrics-operator` | `ibm-software-central` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Subscription` | `ibm-data-reporter-operator` | `ibm-software-central` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `MarketplaceConfig` | `marketplaceconfig` | `ibm-software-central` | When `application_admin_role` is true | `application_admin_role` |
| `ClusterRole` | DRO cluster roles | N/A (cluster-scoped) | When `cluster_admin_role` is true | `cluster_admin_role` |
| `ClusterRoleBinding` | `metric-state-view-binding` | N/A (cluster-scoped) | When `cluster_admin_role` is true | `cluster_admin_role` |
| `ClusterRoleBinding` | `reporter-cluster-monitoring-binding` | N/A (cluster-scoped) | When `cluster_admin_role` is true | `cluster_admin_role` |
| `ClusterRoleBinding` | `manager-cluster-monitoring-binding` | N/A (cluster-scoped) | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Certificate` | DRO certificate resources | `ibm-software-central` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `ClusterIssuer` | DRO cluster issuer resources | N/A (cluster-scoped) | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Secret` | `ibm-data-reporter-operator-api-token` | `ibm-software-central` | When `application_admin_role` is true | `application_admin_role` |
| `Secret` | `aws` | `ibm-software-central` | When `application_admin_role` and `run_sync_hooks` are true | `application_admin_role` |
| `ServiceAccount` | `postsync-ibm-dro-update-sm-sa` | `ibm-software-central` | When `application_admin_role` and `run_sync_hooks` are true | `application_admin_role` |
| `Role` | `postsync-ibm-dro-update-sm-r` | `ibm-software-central` | When `application_admin_role` and `run_sync_hooks` are true | `application_admin_role` |
| `RoleBinding` | `postsync-ibm-dro-update-sm-rb` | `ibm-software-central` | When `application_admin_role` and `run_sync_hooks` are true | `application_admin_role` |
| `Job` | `postsync-ibm-dro-update-sm-job-*` | `ibm-software-central` | When `application_admin_role` and `run_sync_hooks` are true | `application_admin_role` |
| `Secret` | `dest-header-map-secret` | `ibm-software-central` | When `cluster_admin_role` and `dro_cmm_setup` are true | `cluster_admin_role` |
| `Secret` | `auth-header-map-secret` | `ibm-software-central` | When `cluster_admin_role` and `dro_cmm_setup` are true | `cluster_admin_role` |
| `Secret` | `auth-body-data-secret` | `ibm-software-central` | When `cluster_admin_role` and `dro_cmm_setup` are true | `cluster_admin_role` |
| `ConfigMap` | `kazaam-configmap` | `ibm-software-central` | When `cluster_admin_role` and `dro_cmm_setup` are true | `cluster_admin_role` |
| `DataReporterConfig` | `datareporterconfig` | `ibm-software-central` | When `cluster_admin_role` and `dro_cmm_setup` are true | `cluster_admin_role` |
