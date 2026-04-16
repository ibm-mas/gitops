IBM AISERVICE Tenant
===============================================================================
Deploy and configure aiservice tenant with configurable version

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Namespace` | AI Service tenant namespace | Tenant namespace | Always | `application_admin_role` |
| `Secret` | Tenant RSL/SLS/DRO/WX secrets | Tenant namespace | Always | `application_admin_role` |
| `OperatorGroup` | AI Service tenant operator group | Tenant namespace | Always | `application_admin_role` |
| `Subscription` | AI Service tenant operator subscription | Tenant namespace | Always | `application_admin_role` |
| `AIServiceTenant` | AI Service tenant CR | Tenant namespace | Always | `application_admin_role` |
| `ServiceAccount` | Migration and post-sync service accounts | Tenant namespace | Always | `application_admin_role` |
| `Role` | Migration and post-sync roles | Tenant namespace | Always | `application_admin_role` |
| `RoleBinding` | Migration and post-sync role bindings | Tenant namespace | Always | `application_admin_role` |
| `NetworkPolicy` | Tenant migration and ingress network policies | Tenant namespace | Always | `application_admin_role` |
| `Job` | Migration, post-sync, and secret setup jobs | Tenant namespace | Always | `application_admin_role` |