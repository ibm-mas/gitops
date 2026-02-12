Redhat OpenShift cert-manager Operator
===============================================================================
Installs Redhat OpenShift cert-manager Operator in cert-manager-operator namespace

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `operatorgroup` | `cert-manager-operator` | Always | `cluster_admin_role` |
| `Subscription` | `openshift-cert-manager-operator` | `cert-manager-operator` | Always | `cluster_admin_role` |
| `Job` | `postsync-rhcm-update-sm-job-*` | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |

**Note:** The PostSync Job updates AWS Secrets Manager with cluster information for use by other charts.
