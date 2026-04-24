Custom Service Accounts
===============================================================================
Creates configurable service accounts with assigned rbac

<!--docs-include-start-->


## Configuration

### Values

```yaml
custom_sa:
  # Namespace where custom service accounts will be created
  # Default: default
  custom_sa_namespace: "default"

  # Custom service account details (required)
  # Map of service account names to ClusterRole names
  # Format: key-value pairs where key is SA name and value is ClusterRole
  # Example:
  #   my-app-sa: view
  #   automation-sa: edit
  #   admin-sa: cluster-admin
  custom_sa_details: {}
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

**Single service account with view permissions:**
```yaml
custom_sa:
  custom_sa_namespace: "default"
  custom_sa_details:
    readonly-sa: view
```

**Multiple service accounts with different roles:**
```yaml
custom_sa:
  custom_sa_namespace: "automation"
  custom_sa_details:
    app-reader: view
    app-editor: edit
    app-admin: admin
    cluster-viewer: cluster-reader
```

**Service accounts in specific namespace:**
```yaml
custom_sa:
  custom_sa_namespace: "mas-prod-core"
  custom_sa_details:
    pipeline-sa: edit
    monitoring-sa: view
    backup-sa: admin
```

### How It Works

1. Creates a ServiceAccount in the specified namespace for each entry in `custom_sa_details`
2. Creates a ClusterRoleBinding that binds the ServiceAccount to the specified ClusterRole
3. Optionally runs a PostSync hook to store the ServiceAccount tokens in AWS Secrets Manager

### Common ClusterRoles

- `view` - Read-only access to most objects
- `edit` - Read/write access to most objects (no RBAC changes)
- `admin` - Full access within a namespace
- `cluster-admin` - Full cluster access
- `cluster-reader` - Read-only cluster access

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ServiceAccount` | `<custom_sa_name>` | Configurable via `custom_sa_namespace` | For each entry in `custom_sa_details` | `cluster_admin_role` |
| `ClusterRoleBinding` | `<custom_sa_name>-crb` | N/A (cluster-scoped) | For each entry in `custom_sa_details` | `cluster_admin_role` |
| `Secret` | `postsync-custom-sa-update-sm` | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |
| `ServiceAccount` | `postsync-custom-sa-update-sm-sa` | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |
| `Role` | `postsync-custom-sa-update-sm-role` | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |
| `RoleBinding` | `postsync-custom-sa-update-sm-rolebinding` | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |
| `ClusterRole` | `postsync-custom-sa-update-sm-cluster-role` | N/A (cluster-scoped) | When `run_sync_hooks` is true | `cluster_admin_role` |
| `ClusterRoleBinding` | `postsync-custom-sa-update-sm-cluster-rolebinding` | N/A (cluster-scoped) | When `run_sync_hooks` is true | `cluster_admin_role` |
| `Job` | `postsync-custom-sa-update-sm-job-*` | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |

**Note:** Service accounts are created dynamically based on the `custom_sa_details` configuration. Each service account is bound to a specified ClusterRole. The PostSync Job updates AWS Secrets Manager with service account tokens.
