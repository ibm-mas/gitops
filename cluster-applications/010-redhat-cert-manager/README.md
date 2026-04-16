Redhat OpenShift cert-manager Operator
===============================================================================
Installs Redhat OpenShift cert-manager Operator in cert-manager-operator namespace

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
