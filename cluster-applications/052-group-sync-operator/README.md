Group Sync Operator
===============================================================================
Installs the Group Sync Operator. Minimum required version: 0.0.31

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `group-sync-operator` | `group-sync-operator` | Always | `cluster_admin_role` |
| `Subscription` | `group-sync-operator` | `group-sync-operator` | Always | `cluster_admin_role` |
| `Secret` | `isv-group-sync` | `group-sync-operator` | Always | `cluster_admin_role` |
| `GroupSync` | `isv-group-sync` | `group-sync-operator` | Always | `cluster_admin_role` |

**Note:** The GroupSync resource synchronizes groups from IBM Security Verify based on the configured schedule.
