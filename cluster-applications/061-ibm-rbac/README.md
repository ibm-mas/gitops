IBM Resource-Based Access Control (RBAC)
===============================================================================
Installs the IBM RBAC roles and role bindings. Groups are managed by the Group Sync Operator.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ClusterRole` | `dba` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRole` | `network` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRole` | `sre-editor` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `cluster-admin` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `dba-editor` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `dba-reader` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `network-reader` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `network` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `provisioning` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `sre-automation-admin` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `sre-editor` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `sre-reader` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `Group` | OpenShift groups referenced by IBM RBAC bindings | N/A (cluster-scoped) | Always | `cluster_admin_role` |

**Note:** ClusterRoleBindings reference groups that are synchronized by the Group Sync Operator.
