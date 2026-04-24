IBM Suite License Service
===============================================================================
Installs the `ibm-sls` operator and creates an instance of the `LicenseService`.

Contains a job that runs last (`07-postsync-update-sm_Job.yaml`). This registers the `${ACCOUNT_ID}/${CLUSTER_ID}/${INSTANCE_ID}/sls` secret in the **Secrets Vault** used to share some information that is generated at runtime with other ArgoCD Applications.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `ibm-sls` | Instance SLS namespace | Always | `application_admin_role` |
| `Subscription` | `ibm-sls` | Instance SLS namespace | Always | `application_admin_role` |
| `Secret` | `ibm-entitlement` | Instance SLS namespace | Always | `application_admin_role` |
| `Secret` | `mongo-credentials` | Instance SLS namespace | Always | `application_admin_role` |
| `Secret` | `sls-entitlement` | Instance SLS namespace | Always | `application_admin_role` |
| `LicenseService` | `sls` instance CR | Instance SLS namespace | Always | `application_admin_role` |
| `NetworkPolicy` | post-sync update secret manager network policy | Instance SLS namespace | Always | `application_admin_role` |
| `Secret` | post-sync update secret manager runtime secret | Instance SLS namespace | Always | `application_admin_role` |
| `ServiceAccount` | post-sync update secret manager service account | Instance SLS namespace | Always | `application_admin_role` |
| `Role` | post-sync update secret manager roles | Instance SLS namespace | Always | `application_admin_role` |
| `RoleBinding` | post-sync update secret manager role binding | Instance SLS namespace | Always | `application_admin_role` |
| `Job` | post-sync update secret manager job | Instance SLS namespace | Always | `application_admin_role` |