IBM MAS Provisioner (For Internal Use Only)
===============================================================================
Installs the MAS Provisioner service which sends a notification when an order comes through AWS market place. The MAS provisioner service broker is intended for internal use only.

<!--docs-include-start-->


## Configuration

### Values

```yaml
mas_provisioner:
  # Account alias (required)
  # Identifier for the AWS account
  account_alias: ""

  # IBM Entitlement Key (required)
  # Your IBM entitlement key for accessing IBM container images
  ibm_entitlement: ""

  # Provisioner domain (required)
  # Domain where the provisioner service will be exposed
  # Example: provisioner.mas.example.com
  provisioner_domain: ""

  # Provisioner namespace (required)
  # Namespace where provisioner will be deployed
  # Default: mas-provisioner
  provisioner_namespace: "mas-provisioner"

  # Provisioner version (required)
  # Container image version for the provisioner service
  provisioner_version: ""

  # Enable mTLS (required)
  # Enable mutual TLS for secure communication
  # Options: true or false
  enable_mtls: false

  # Service port (required)
  # Port number for the provisioner service
  # Default: 8080
  service_port: 8080

  # Status repository URL (required)
  # Git repository URL for storing provisioning status
  status_repo_url: ""

  # MAS annotations repository URL (required)
  # Git repository URL for MAS annotations
  mas_annotations_repo_url: ""

  # Base branch (required)
  # Git branch to use for repositories
  # Default: main
  base_branch: "main"

  # Async poll interval (required)
  # Polling interval in seconds for async operations
  # Default: 30
  async_poll_interval: 30

  # Async poll max (required)
  # Maximum number of polling attempts
  # Default: 100
  async_poll_max: 100

  # Enable PagerDuty alerts (required)
  # Enable alerting via PagerDuty
  # Options: true or false
  enable_pd_alert: false

  # Enable OCM alerts (required)
  # Enable alerting via OpenShift Cluster Manager
  # Options: true or false
  enable_ocm_alert: false

  # GitHub token (required)
  # Personal access token for GitHub API access
  github_token: ""

  # Storage class (optional)
  # Storage class for persistent volumes
  storage_class: ""

  # Git root CA certificate (optional)
  # Root CA certificate for Git server TLS verification
  git_root_ca: ""

  # CSB client CA certificate (optional)
  # Client CA certificate for Cloud Service Broker
  csb_client_ca: ""

  # Instana API token (optional)
  # API token for Instana monitoring integration
  instana_api_token: ""

  # Instana URL prefix (optional)
  # URL prefix for Instana backend
  # Example: https://instana.example.com
  instana_url_prefix: ""

  # OCM API token (optional)
  # API token for OpenShift Cluster Manager
  ocm_api_token: ""

  # PagerDuty integration key (optional)
  # Integration key for PagerDuty alerts
  pagerduty_integration: ""
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

**Basic provisioner configuration:**
```yaml
mas_provisioner:
  account_alias: "mas-prod"
  ibm_entitlement: "your-entitlement-key"
  provisioner_domain: "provisioner.mas.example.com"
  provisioner_namespace: "mas-provisioner"
  provisioner_version: "1.0.0"
  enable_mtls: false
  service_port: 8080
  status_repo_url: "https://github.com/my-org/mas-status"
  mas_annotations_repo_url: "https://github.com/my-org/mas-annotations"
  base_branch: "main"
  async_poll_interval: 30
  async_poll_max: 100
  enable_pd_alert: false
  enable_ocm_alert: false
  github_token: "ghp_xxxxxxxxxxxx"
```

**With monitoring and alerting:**
```yaml
mas_provisioner:
  account_alias: "mas-prod"
  ibm_entitlement: "your-entitlement-key"
  provisioner_domain: "provisioner.mas.example.com"
  provisioner_namespace: "mas-provisioner"
  provisioner_version: "1.0.0"
  enable_mtls: true
  service_port: 8443
  status_repo_url: "https://github.com/my-org/mas-status"
  mas_annotations_repo_url: "https://github.com/my-org/mas-annotations"
  base_branch: "main"
  async_poll_interval: 30
  async_poll_max: 100
  enable_pd_alert: true
  enable_ocm_alert: true
  github_token: "ghp_xxxxxxxxxxxx"
  storage_class: "gp3"
  instana_api_token: "your-instana-token"
  instana_url_prefix: "https://instana.example.com"
  ocm_api_token: "your-ocm-token"
  pagerduty_integration: "your-pd-integration-key"
```

**With custom certificates:**
```yaml
mas_provisioner:
  account_alias: "mas-prod"
  ibm_entitlement: "your-entitlement-key"
  provisioner_domain: "provisioner.mas.example.com"
  provisioner_namespace: "mas-provisioner"
  provisioner_version: "1.0.0"
  enable_mtls: true
  service_port: 8443
  status_repo_url: "https://github.enterprise.com/my-org/mas-status"
  mas_annotations_repo_url: "https://github.enterprise.com/my-org/mas-annotations"
  base_branch: "main"
  async_poll_interval: 30
  async_poll_max: 100
  enable_pd_alert: false
  enable_ocm_alert: false
  github_token: "ghp_xxxxxxxxxxxx"
  git_root_ca: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  csb_client_ca: |
    -----BEGIN CERTIFICATE-----
  ...
  -----END CERTIFICATE-----
```

### Important Notes

- **Internal Use Only**: This service is designed for internal IBM use and handles AWS Marketplace order notifications
- **Security**: Always use mTLS in production environments
- **Monitoring**: Enable Instana integration for production deployments
- **Alerting**: Configure PagerDuty or OCM alerts for critical notifications

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | `ibm-entitlement` | `mas-provisioner` | Always | `cluster_admin_role` |
| `ServiceAccount` | `mas-provisioner` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Issuer` | `mas-provisioner-selfsigned-issuer` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Certificate` | `mas-provisioner-ca` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Issuer` | `mas-provisioner-ca-issuer` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Certificate` | `mas-provisioner-cert` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Certificate` | `mas-provisioner-console-cert` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Secret` | `ibm-cos-credentials` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Secret` | `ibm-sls-credentials` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Secret` | `ibm-mongo-credentials` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Secret` | `ibm-gitops-credentials` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Secret` | `mas-provisioner-callback-url` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Secret` | `mas-provisioner-storage` | `mas-provisioner` | Always | `cluster_admin_role` |
| `PersistentVolumeClaim` | `mas-provisioner-pvc` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Service` | `mas-provisioner` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Service` | `mas-provisioner-console` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Deployment` | `mas-provisioner` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Route` | `mas-provisioner` | `mas-provisioner` | Always | `cluster_admin_role` |

**Note:** This service is for internal IBM use only and handles AWS Marketplace order notifications.
