Cluster Logging Operator
===============================================================================
Installs the Cluster Logging Operator. For further info see https://docs.openshift.com/container-platform/4.12/observability/logging/cluster-logging.html (replace version in URL with OpenShift version)

<!--docs-include-start-->


Also installs log forwarder for non-MCSP accounts or when indicated.

## Configuration

### Values

```yaml
cluster_logging_operator:
  # Enable cluster logging operator installation
  # Set to false to skip installation
  # Default: true
  install: true

  # AWS credentials for CloudWatch log forwarding (required)
  # IAM user credentials with CloudWatch Logs write permissions
  aws_access_key_id: ""
  aws_secret_access_key: ""

  # Cluster Logging Operator subscription channel
  # Default: stable
  channel: "stable"

  # Install plan approval strategy
  # Options: "Automatic" or "Manual"
  # Default: Automatic
  install_plan: Automatic

  # Enable syslog forwarder
  # When true, uses syslog forwarder instead of direct CloudWatch forwarding
  # Default: false
  use_syslog_forwarder: false

  # Setup log forwarding configuration (optional)
  # When true, configures additional log forwarding resources
  # Default: false
  setup_log_forwarding: false

  # Log forwarder client URL (required when setup_log_forwarding is true)
  # URL of the syslog receiver endpoint
  log_forwarder_client_url: ""

  # Syslog forwarder version (required when setup_log_forwarding is true)
  # Container image version for the syslog forwarder
  syslog_forwarder_version: ""

  # Log forwarder pull secret (required when setup_log_forwarding is true)
  # Secret for pulling syslog forwarder container image
  log_forwarder_pullsecret: ""

  # DLC CA certificate bundle (required when setup_log_forwarding is true)
  # CA certificate bundle for TLS verification
  log_forwarder_dlc_cert: ""
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

**Basic CloudWatch logging:**
```yaml
cluster_logging_operator:
  install: true
  aws_access_key_id: "AKIAIOSFODNN7EXAMPLE"
  aws_secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  channel: "stable"
  install_plan: Automatic
  use_syslog_forwarder: false
  setup_log_forwarding: false
```

**With syslog forwarder:**
```yaml
cluster_logging_operator:
  install: true
  aws_access_key_id: "AKIAIOSFODNN7EXAMPLE"
  aws_secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  channel: "stable"
  install_plan: Automatic
  use_syslog_forwarder: true
  setup_log_forwarding: true
  log_forwarder_client_url: "syslog://logs.example.com:514"
  syslog_forwarder_version: "1.0.0"
  log_forwarder_pullsecret: "your-pull-secret"
  log_forwarder_dlc_cert: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
```

**Manual operator updates:**
```yaml
cluster_logging_operator:
  install: true
  aws_access_key_id: "AKIAIOSFODNN7EXAMPLE"
  aws_secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  channel: "stable"
  install_plan: Manual
  use_syslog_forwarder: false
  setup_log_forwarding: false
```

### Prerequisites

- AWS account with CloudWatch Logs enabled
- IAM credentials with CloudWatch Logs write permissions
- For syslog forwarding: syslog receiver endpoint and TLS certificates

For more information, see the [OpenShift Cluster Logging documentation](https://docs.openshift.com/container-platform/latest/observability/logging/cluster-logging.html).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `cluster-logging-operator` | `openshift-logging` | Always | `cluster_admin_role` |
| `Subscription` | `cluster-logging-operator` | `openshift-logging` | Always | `cluster_admin_role` |
| `Secret` | `cloudwatch` | `openshift-logging` | Always | `cluster_admin_role` |
| `ClusterLogging` | `instance` | `openshift-logging` | When channel version ≤ 5.9 | `cluster_admin_role` |
| `ClusterLogForwarder` | `instance` | `openshift-logging` | Always | `cluster_admin_role` |
| `ServiceAccount` | `collector` | `openshift-logging` | When channel version ≥ 6.0 | `cluster_admin_role` |
| `ClusterRole` | `collect-application-logs` | N/A (cluster-scoped) | When channel version ≥ 6.0 | `cluster_admin_role` |
| `ClusterRole` | `collect-audit-logs` | N/A (cluster-scoped) | When channel version ≥ 6.0 | `cluster_admin_role` |
| `ClusterRole` | `collect-infrastructure-logs` | N/A (cluster-scoped) | When channel version ≥ 6.0 | `cluster_admin_role` |
| `ClusterRoleBinding` | `collect-application-logs` | N/A (cluster-scoped) | When channel version ≥ 6.0 | `cluster_admin_role` |
| `ClusterRoleBinding` | `collect-audit-logs` | N/A (cluster-scoped) | When channel version ≥ 6.0 | `cluster_admin_role` |
| `ClusterRoleBinding` | `collect-infrastructure-logs` | N/A (cluster-scoped) | When channel version ≥ 6.0 | `cluster_admin_role` |
| `ServiceAccount` | `syslog-forwarder` | `openshift-logging` | When `setup_log_forwarding` is true | `cluster_admin_role` |
| `ClusterRole` | `syslog-forwarder` | N/A (cluster-scoped) | When `setup_log_forwarding` is true | `cluster_admin_role` |
| `ClusterRoleBinding` | `syslog-forwarder` | N/A (cluster-scoped) | When `setup_log_forwarding` is true | `cluster_admin_role` |
| `Secret` | `syslog-pullsecret` | `openshift-logging` | When `setup_log_forwarding` is true | `cluster_admin_role` |
| `Secret` | `dlc-cert` | `openshift-logging` | When `setup_log_forwarding` is true | `cluster_admin_role` |
| `Secret` | `syslog-forwarder` | `openshift-logging` | When `setup_log_forwarding` is true | `cluster_admin_role` |
| `ConfigMap` | `syslog-forwarder` | `openshift-logging` | When `setup_log_forwarding` is true | `cluster_admin_role` |
| `Service` | `syslog-forwarder` | `openshift-logging` | When `setup_log_forwarding` is true | `cluster_admin_role` |
| `Deployment` | `syslog-forwarder` | `openshift-logging` | When `setup_log_forwarding` is true | `cluster_admin_role` |

**Note:** The syslog forwarder resources are only created when `setup_log_forwarding` is enabled. The `ClusterLogForwarder` resource is created for both supported operator version ranges, but the API group and collector RBAC differ between channel versions.
