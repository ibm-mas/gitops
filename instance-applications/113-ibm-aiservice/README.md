IBM AISERVICE
===============================================================================
Deploy and configure AISERVICE with configurable version

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | AI Service S3/DRO/JDBC/knowledge-model secrets | AI Service namespace | Always | `application_admin_role` |
| `OperatorGroup` | AI Service operator group | AI Service namespace | Always | `application_admin_role` |
| `Subscription` | AI Service operator subscription | AI Service namespace | Always | `application_admin_role` |
| `AIServiceApp` | AI Service application CR | AI Service namespace | Always | `application_admin_role` |
| `ServiceAccount` | Post-sync migration service account | AI Service namespace | Always | `application_admin_role` |
| `Role` | Post-sync migration roles | AI Service namespace | Always | `application_admin_role` |
| `RoleBinding` | Post-sync migration role binding | AI Service namespace | Always | `application_admin_role` |
| `NetworkPolicy` | Post-sync migration network policy | AI Service namespace | Always | `application_admin_role` |
| `Job` | Post-sync migration job | AI Service namespace | Always | `application_admin_role` |