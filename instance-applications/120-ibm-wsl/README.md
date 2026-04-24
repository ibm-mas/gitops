IBM Watson Studio Local (WSL)
===============================================================================
Deploys and configures the CP4D Service, Watson Studio Local (WSL) needed for `MAS Predict`. Deploys WSL operator and its dependencies.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Subscription` | WSL operator subscription | CP4D instance namespace | Always | `application_admin_role` |
| `WS` | Watson Studio Local service CR | CP4D instance namespace | Always | `application_admin_role` |
| `ServiceAccount` | WSL post-verify service account | CP4D instance namespace | Always | `application_admin_role` |
| `Role` | WSL post-verify roles | CP4D instance namespace | Always | `application_admin_role` |
| `RoleBinding` | WSL post-verify role binding | CP4D instance namespace | Always | `application_admin_role` |
| `Secret` | WSL post-verify runtime secret | CP4D instance namespace | Always | `application_admin_role` |
| `Job` | WSL post-verify job | CP4D instance namespace | Always | `application_admin_role` |
