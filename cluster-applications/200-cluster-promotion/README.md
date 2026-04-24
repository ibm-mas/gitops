Cluster Promotion
===============================================================================
Takes cluster level changes and promotes them to the next level

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | `cluster-promoter-<cluster_id>-cm` | `mas-syncres` | Always | `cluster_admin_role` |
| `ServiceAccount` | `cluster-verify-sa` | `mas-syncres` | Always | `cluster_admin_role` |
| `ClusterRole` | `cluster-verify-cr` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `cluster-verify-crb` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `Job` | `cluster-verify-*` | `mas-syncres` | Always | `cluster_admin_role` |
| `Job` | `cluster-promoter-*` | `mas-syncres` | Always | `cluster_admin_role` |

**Note:** The cluster-verify Job validates the cluster state before the cluster-promoter Job promotes configuration changes to the next environment level.