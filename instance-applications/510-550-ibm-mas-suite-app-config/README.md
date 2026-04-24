MAS Application Configuration
===============================================================================
Generic chart for configuring a workspace for a MAS application (a.k.a "activating" the MAS application).
Certain templates are enabled only for specific MAS applications (`mas_app_id`).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `StorageClass` | Application configuration storage classes | Application namespace / cluster | When required by the target MAS app | `application_admin_role` |
| `ConfigMap` | Placeholder, sanity/verify scripts, and runtime config maps | Application namespace | When required by the target MAS app | `application_admin_role` |
| `Secret` | Application-specific configuration secrets | Application namespace | When required by the target MAS app | `application_admin_role` |
| `NetworkPolicy` | Post-sync and recurring job network policies | Application namespace | When associated jobs are enabled | `application_admin_role` |
| `ServiceAccount` | Post-sync and recurring job service accounts | Application namespace | When associated jobs are enabled | `application_admin_role` |
| `Role` | Post-sync and recurring job roles | Application namespace | When associated jobs are enabled | `application_admin_role` |
| `RoleBinding` | Post-sync and recurring job role bindings | Application namespace | When associated jobs are enabled | `application_admin_role` |
| `ClusterRole` | Verify job cluster roles | N/A (cluster-scoped) | When cluster-level verification is enabled | `application_admin_role` |
| `ClusterRoleBinding` | Verify job cluster role bindings | N/A (cluster-scoped) | When cluster-level verification is enabled | `application_admin_role` |
| `CronJob` | Recurring update/app-role cron jobs | Application namespace | When associated recurring jobs are enabled | `application_admin_role` |
| `Job` | Post-sync sanity, verify, and DB/application jobs | Application namespace | When associated jobs are enabled | `application_admin_role` |