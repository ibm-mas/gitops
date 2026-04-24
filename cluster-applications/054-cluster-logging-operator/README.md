Cluster Logging Operator
===============================================================================
Installs the Cluster Logging Operator. For further info see https://docs.openshift.com/container-platform/4.12/observability/logging/cluster-logging.html (replace version in URL with OpenShift version)

Also installs log forwarder for non-MCSP accounts or when indicated.

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
