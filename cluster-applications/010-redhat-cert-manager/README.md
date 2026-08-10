Redhat OpenShift cert-manager Operator
===============================================================================
Installs Redhat OpenShift cert-manager Operator in cert-manager-operator namespace

<!--docs-include-start-->


## Configuration

### Values

```yaml
redhat_cert_manager:
  # Enable sync hooks for post-deployment tasks
  # When true, creates Jobs to update AWS Secrets Manager with cluster information
  # Default: true
  run_sync_hooks: true

  # Subscription channel for the cert-manager operator
  # Default: stable-v1
  channel: stable-v1

  # Install plan approval strategy
  # Options: "Automatic" or "Manual"
  # Default: Automatic
  redhat_cert_manager_install_plan: Automatic
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

**Basic configuration with automatic updates:**
```yaml
redhat_cert_manager:
  run_sync_hooks: true
  channel: stable-v1
  redhat_cert_manager_install_plan: Automatic
```

**Manual approval for updates:**
```yaml
redhat_cert_manager:
  run_sync_hooks: true
  channel: stable-v1
  redhat_cert_manager_install_plan: Manual
```

**Disable sync hooks:**
```yaml
redhat_cert_manager:
  run_sync_hooks: false
  channel: stable-v1
  redhat_cert_manager_install_plan: Automatic
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `operatorgroup` | `cert-manager-operator` | Always | `cluster_admin_role` |
| `Subscription` | `openshift-cert-manager-operator` | `cert-manager-operator` | Always | `cluster_admin_role` |
| `ClusterRole` | cert-manager operator cluster roles | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | cert-manager operator cluster role bindings | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `Secret` | cert-manager related secrets | `cert-manager` and `default` | Always and hook-driven as applicable | `cluster_admin_role` |
| `ServiceAccount` | cert-manager hook service accounts | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |
| `Job` | `postsync-rhcm-update-sm-job-*` | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |

**Note:** The PostSync Job updates AWS Secrets Manager with cluster information for use by other charts.
