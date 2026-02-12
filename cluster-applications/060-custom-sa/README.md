Custom Service Accounts
===============================================================================
Creates configurable service accounts with assigned rbac

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ServiceAccount` | `<custom_sa_name>` | Configurable via `custom_sa_namespace` | For each entry in `custom_sa_details` | `cluster_admin_role` |
| `ClusterRoleBinding` | `<custom_sa_name>-crb` | N/A (cluster-scoped) | For each entry in `custom_sa_details` | `cluster_admin_role` |
| `ClusterRole` | `postsync-custom-sa-update-sm-role` | N/A (cluster-scoped) | When `run_sync_hooks` is true | `cluster_admin_role` |
| `ClusterRoleBinding` | `postsync-custom-sa-update-sm-rolebinding` | N/A (cluster-scoped) | When `run_sync_hooks` is true | `cluster_admin_role` |
| `ServiceAccount` | `postsync-custom-sa-update-sm-sa` | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |
| `Job` | `postsync-custom-sa-update-sm-job-*` | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |

**Note:** Service accounts are created dynamically based on the `custom_sa_details` configuration. Each service account is bound to a specified ClusterRole. The PostSync Job updates AWS Secrets Manager with service account tokens.