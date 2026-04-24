IBM AISERVICE
===============================================================================
Deploy and configure AISERVICE with configurable version

<!--docs-include-start-->


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

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_aiservice:
  aiservice_instance_id: string
  aiservice_namespace: string
  ibm_entitlement_key: string (secret reference)
  
  # DRO Configuration
  drocfg_registration_key: string (secret reference)
  drocfg_url: string (secret reference)
  drocfg_ca_b64enc: string (secret reference)
  aiservice_dro_token_secret: string
  aiservice_dro_cacert_secret: string
  
  environment_type: string
  
  # S3 Configuration
  aiservice_s3_endpoint_url: string
  aiservice_s3_bucket_prefix: string
  aiservice_s3_templates_bucket: string
  aiservice_s3_tenants_bucket: string
  aiservice_s3_secret: string
  aiservice_s3_ssl: string
  aiservice_s3_accesskey: string (secret reference)
  aiservice_s3_secretkey: string (secret reference)
  aiservice_s3_host: string (secret reference)
  aiservice_s3_port: string
  aiservice_s3_region: string (secret reference)
  
  # JDBC Configuration
  jdbccfg_username: string (secret reference)
  jdbccfg_password: string (secret reference)
  jdbccfg_url: string (secret reference)
  jdbccfg_sslenabled: string (secret reference)
  jdbccfg_ca_b64enc: string (secret reference)
  aiservice_jdbc_secret: string
  use_aws_db2: boolean
  
  # MAS Entitlement
  entitlement_key: string (secret reference)
  
  # Development Registry Entitlement
  artifactory_token: string (secret reference)
  
  # Operator Configuration
  aiservice_channel: string
  mas_catalog_source: string
  mas_icr_cp: string
  mas_icr_cpopen: string
  
  aiservice_domain: string
  in_saas_env: boolean
  aiservice_storage_class: string
  aiservice_operator_log_level: string
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
