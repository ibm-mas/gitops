Instana Agent Operator
===============================================================================
Installs the Instana Agent Operator. Additionally, a cron job is installed that 
is responsible for updating the Instana agent custom resource with the connection
information for each DB2 instance in the cluster.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `instana-agent` | `instana-agent` | Always | `cluster_admin_role` |
| `Subscription` | `instana-agent` | `instana-agent` | Always | `cluster_admin_role` |
| `InstanaAgent` | `instana-agent` | `instana-agent` | Always | `cluster_admin_role` |
| `PersistentVolumeClaim` | `instana-agent` | `instana-agent` | Always | `cluster_admin_role` |
| `Secret` | `instana-agent-key` | `instana-agent` | Always | `cluster_admin_role` |
| `Secret` | `db2-passwords` | `instana-agent` | Always | `cluster_admin_role` |
| `ClusterRole` | `instana-agent-db2-config-role` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ServiceAccount` | `instana-agent-db2-config-sa` | `instana-agent` | Always | `cluster_admin_role` |
| `Role` | `instana-agent-db2-config-role` | `instana-agent` | Always | `cluster_admin_role` |
| `RoleBinding` | `instana-agent-db2-config-role` | `instana-agent` | Always | `cluster_admin_role` |
| `RoleBinding` | `instana-agent-db2-config-sa-edit` | `instana-agent` | Always | `cluster_admin_role` |
| `NetworkPolicy` | `instana-agent-db2-config-netpol` | `instana-agent` | Always | `cluster_admin_role` |
| `CronJob` | `instana-agent-db2-config` | `instana-agent` | Always | `cluster_admin_role` |

**Note:** The CronJob automatically updates the InstanaAgent configuration with DB2 instance connection details.
