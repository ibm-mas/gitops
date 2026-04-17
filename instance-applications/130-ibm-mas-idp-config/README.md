IDP Configuration for MAS Core Platform
===============================================================================
Create a IdpCfg CR instance and associated credentials secret for use by MAS.
Currently only supports LDAP.

Contains a post-delete hook (`postdelete-delete-cr.yaml`) that will ensure the config CR is deleted when the ArgoCD application managing this chart is deleted (this will not happen by default as the config CR is asserted to be owned by the `Suite` CR by the MAS entity managers).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | LDAP credential secret | MAS core namespace | Always | `application_admin_role` |
| `IDPCfg` | MAS IDP configuration CR | MAS core namespace | Always | `application_admin_role` |
| `Job` | Post-delete IDP config cleanup job | MAS core namespace | On application deletion | `application_admin_role` |