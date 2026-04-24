IBM Suite License Service
===============================================================================
Installs the `ibm-sls` operator and creates an instance of the `LicenseService`.

<!--docs-include-start-->


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

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_sls:
  # SaaS Licensing (when using IBM Customer Number)
  ibm_customer_number: string (optional)
  subscription_id: string (optional)
  
  # Traditional Licensing (when not using ICN)
  sls_channel: string
  sls_entitlement_file: string (secret reference)
  ibm_entitlement_key: string (secret reference)
  
  # MongoDB Configuration
  mongodb_provider: string
  user_action: string
  docdb_host: string (secret reference)
  docdb_port: string (secret reference)
  docdb_master_username: string (secret reference)
  docdb_master_password: string (secret reference)
  docdb_master_info: string (secret reference)
  sls_mongo_username: string (secret reference)
  sls_mongo_password: string (secret reference)
  sls_mongo_secret_name: string
  
  # Operator Configuration
  icr_cp_open: string
  sls_install_plan: string
  run_sync_hooks: boolean
  
  # MongoDB Specification
  mongo_spec:
    authMechanism: string
    configDb: string
    secretName: string
    retryWrites: boolean (optional)
    nodes:
      - host: string
        port: number
    certificates:
      - alias: string
        crt: string (multiline)
  
  # Certificate Authority (optional)
  internal_certificate_authority: string
```

**Note**: Values marked with "(secret reference)" should use the format `<path:secrets/path:key>` to reference secrets stored in the Secrets Vault.

## Base Instance Values

This chart inherits common instance configuration values. The most frequently used base values are:

```yaml
account:
  id: string                    # Account identifier
  name: string                  # Account name

region:
  id: string                    # Region identifier
  name: string                  # Region name

cluster:
  id: string                    # Cluster identifier
  name: string                  # Cluster name

instance:
  id: string                    # MAS instance identifier

sm:                             # Secrets Manager configuration
  aws_secret_region: string
  aws_access_key_id: string (secret reference)
  aws_secret_access_key: string (secret reference)
```

For complete documentation of all base instance values including optional fields like `custom_labels`, `argocluster_instance`, `application_admin_service_account`, `mas_wipe_mongo_data`, `allow_list`, `additional_vpn`, `application_configuration`, `use_postdelete_hooks`, `additional_resources`, `extensions`, `enhanced_dr`, and `cli_image_repo`, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md).
