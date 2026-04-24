MAS Core Platform
===============================================================================
Installs the `ibm-mas` operator and creates an instance of the `Suite`.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ClusterIssuer` | IBM CIS cluster issuers | N/A (cluster-scoped) | When CIS integration is enabled | `application_admin_role` |
| `OperatorGroup` | IBM MAS operator group | MAS core namespace | Always | `application_admin_role` |
| `Secret` | Suite certificate and entitlement secrets | MAS core namespace | Always | `application_admin_role` |
| `Subscription` | IBM MAS operator subscription | MAS core namespace | Always | `application_admin_role` |
| `Suite` | MAS Suite CR | MAS core namespace | Always | `application_admin_role` |
| `NetworkPolicy` | Post-sync and post-delete job network policies | MAS core namespace | When associated jobs are enabled | `application_admin_role` |
| `ServiceAccount` | Post-sync and post-delete job service accounts | MAS core namespace | When associated jobs are enabled | `application_admin_role` |
| `Role` | Post-sync and post-delete job roles | MAS core namespace | When associated jobs are enabled | `application_admin_role` |
| `RoleBinding` | Post-sync and post-delete job role bindings | MAS core namespace | When associated jobs are enabled | `application_admin_role` |
| `Job` | Post-sync suite configuration jobs | MAS core namespace | When associated jobs are enabled | `application_admin_role` |
| `ConfigMap` | Welcome message/config job data | MAS core namespace | When welcome-message job is enabled | `application_admin_role` |
