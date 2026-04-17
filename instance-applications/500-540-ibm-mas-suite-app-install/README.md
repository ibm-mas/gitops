MAS Application Install
===============================================================================
Generic chart for installing a MAS Application.
Certain templates are enabled only for specific MAS editions (`mas_edition`) and/or applications (`mas_app_id`).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `StorageClass` | Application-specific storage classes | Application namespace / cluster | When required by the target MAS app | `application_admin_role` |
| `ConfigMap` | Placeholder and JVM/custom config maps | Application namespace | When required by the target MAS app | `application_admin_role` |
| `NetworkPolicy` | Pre/post-sync SCC job network policies | Application namespace | When sync hook jobs are enabled | `application_admin_role` |
| `ServiceAccount` | Pre/post-sync SCC job service accounts | Application namespace | When sync hook jobs are enabled | `application_admin_role` |
| `ClusterRole` | SCC management cluster roles | N/A (cluster-scoped) | When sync hook jobs are enabled | `application_admin_role` |
| `ClusterRoleBinding` | SCC management cluster role bindings | N/A (cluster-scoped) | When sync hook jobs are enabled | `application_admin_role` |
| `Secret` | Entitlement and suite certificate secrets | Application namespace | When required by the target MAS app | `application_admin_role` |
| `OperatorGroup` | MAS application operator group | Application namespace | When required by the target MAS app | `application_admin_role` |
| `ResourceQuota` | MVI resource quota | Application namespace | When required by the target MAS app | `application_admin_role` |
| `Subscription` | MAS application operator subscription | Application namespace | When required by the target MAS app | `application_admin_role` |
| `Job` | Pre/post-sync SCC management jobs | Application namespace | When sync hook jobs are enabled | `application_admin_role` |