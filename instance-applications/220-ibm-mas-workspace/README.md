MAS Core Platform workspace
===============================================================================
Installs the workspace needed for the `Suite`.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Workspace` | MAS workspace CR | MAS core namespace | Always | `application_admin_role` |
| `NetworkPolicy` | Post-sync workspace label job network policy | MAS core namespace | When post-sync job is enabled | `application_admin_role` |
| `ServiceAccount` | Post-sync workspace label service account | MAS core namespace | When post-sync job is enabled | `application_admin_role` |
| `Role` | Post-sync workspace label roles | MAS core namespace | When post-sync job is enabled | `application_admin_role` |
| `RoleBinding` | Post-sync workspace label role binding | MAS core namespace | When post-sync job is enabled | `application_admin_role` |
| `Job` | Post-sync workspace label job | MAS core namespace | When post-sync job is enabled | `application_admin_role` |
