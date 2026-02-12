Cluster Logging Operator
===============================================================================
Installs the Cluster Logging Operator. For further info see https://docs.openshift.com/container-platform/4.12/observability/logging/cluster-logging.html (replace version in URL with OpenShift version)

Also installs log forwarder for non-MCSP accounts or when indicated.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `cluster-logging` | `openshift-logging` | Always | `cluster_admin_role` |
| `ClusterRole` | `cluster-logging-application-view` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `Subscription` | `cluster-logging` | `openshift-logging` | Always | `cluster_admin_role` |
| `Secret` | `cloudwatch-credentials` | `openshift-logging` | Always | `cluster_admin_role` |
| `ConfigMap` | `syslog-forwarder-config` | `openshift-logging` | When `setup_log_forwarding` is true | `cluster_admin_role` |
| `ClusterLogging` | `instance` | `openshift-logging` | When channel version ≤ 5.9 | `cluster_admin_role` |
| `Service` | `syslog-forwarder` | `openshift-logging` | When `setup_log_forwarding` is true | `cluster_admin_role` |
| `ClusterLogForwarder` | `instance` | `openshift-logging` | When channel version ≤ 5.9 | `cluster_admin_role` |
| `Deployment` | `syslog-forwarder` | `openshift-logging` | When `setup_log_forwarding` is true | `cluster_admin_role` |

**Note:** The syslog forwarder resources are only created when `setup_log_forwarding` is enabled.
