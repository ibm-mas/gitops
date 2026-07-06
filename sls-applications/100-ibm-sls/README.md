IBM Suite License Service
===============================================================================
Installs the `ibm-sls` operator and creates an instance of the `LicenseService`.

Contains a job that runs last (`08-postsync-update-sm_Job.yaml`). This registers the `${ACCOUNT_ID}<sep>${ICN}<sep>${SAAS_SUB_ID}<sep>sls` secret in the **Secrets Vault** used to share some information that is generated at runtime with other ArgoCD Applications. When the backend is AWS, `<sep>` is `/`. When the backend is `kubernetessecret`, the secret is created as a Kubernetes Secret in the namespace specified by `sm_secrets_path`.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `operatorgroup` | `mas-<icn>-<subscription_id>-sls` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Subscription` | `ibm-sls` | `mas-<icn>-<subscription_id>-sls` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Secret` | SLS entitlement, Mongo, and image pull secrets | `mas-<icn>-<subscription_id>-sls` | Application resources always when `application_admin_role` is true | `application_admin_role` |
| `Secret` | `aws` — AWS credentials for hook | `mas-<icn>-<subscription_id>-sls` | When sync hooks run and `sm_backend` is not `kubernetessecret` | `application_admin_role` |
| `LicenseService` | `sls` | `mas-<icn>-<subscription_id>-sls` | When `application_admin_role` is true | `application_admin_role` |
| `Job` | SLS DNS and post-sync update jobs | `mas-<icn>-<subscription_id>-sls` | DNS job when `dns_provider` is set; post-sync job when `run_sync_hooks` and `application_admin_role` are true | `application_admin_role` |
| `NetworkPolicy` | `postsync-ibm-sls-update-sm-np` | `mas-<icn>-<subscription_id>-sls` | When `run_sync_hooks` and `application_admin_role` are true | `application_admin_role` |
| `ServiceAccount` | `postsync-ibm-sls-update-sm-sa` | `mas-<icn>-<subscription_id>-sls` | When `run_sync_hooks` and `application_admin_role` are true | `application_admin_role` |
| `Role` | `postsync-ibm-sls-update-sm-r` | `mas-<icn>-<subscription_id>-sls` | When `run_sync_hooks` and `application_admin_role` are true | `application_admin_role` |
| `RoleBinding` | `postsync-ibm-sls-update-sm-rb` | `mas-<icn>-<subscription_id>-sls` | When `run_sync_hooks` and `application_admin_role` are true | `application_admin_role` |
| `Role` | `postsync-ibm-sls-update-sm-r-secrets` — secrets RBAC | `sm_secrets_path` namespace | When `run_sync_hooks`, `application_admin_role`, and `sm_backend` is `kubernetessecret` | `application_admin_role` |
| `RoleBinding` | `postsync-ibm-sls-update-sm-rb-secrets` — secrets RBAC | `sm_secrets_path` namespace | When `run_sync_hooks`, `application_admin_role`, and `sm_backend` is `kubernetessecret` | `application_admin_role` |

## Configuration

### Base Values

```yaml
sm:                             # Secrets Manager configuration
  aws_access_key_id: string (secret reference)
  aws_secret_access_key: string (secret reference)
  backend: string               # aws (default) or kubernetessecret
  secrets_path: string          # Required when backend is kubernetessecret — target namespace for Kubernetes Secrets
```
