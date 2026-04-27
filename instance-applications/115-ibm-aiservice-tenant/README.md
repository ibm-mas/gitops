IBM AISERVICE Tenant
===============================================================================
Deploy and configure aiservice tenant with configurable version

<!--docs-include-start-->


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

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_aiservice_tenant:
  # AI Service Configuration
  tenant_id: string
  aiservice_namespace: string
  aiservice_instance_id: string
  catalog_channel: string
  catalog_source: string
  tenantNamespace: string
  
  mas_icr_cp: string
  mas_icr_cpopen: string
  
  # DRO Configuration
  drocfg_url: string
  drocfg_registration_key: string (secret reference)
  drocfg_ca_b64enc: string (secret reference)
  
  # SLS Configuration
  slscfg_ca_b64enc: string (secret reference)
  slscfg_url: string (secret reference)
  slscfg_registration_key: string (secret reference)
  aiservice_sls_subscription_id: string
  
  # RSL Configuration
  rsl_url: string
  rsl_org_id: string (secret reference)
  rsl_token: string (secret reference)
  rsl_ca_crt: string (secret reference)
  
  # S3 Configuration for Manage Job
  aiservice_s3_accesskey: string (secret reference)
  aiservice_s3_secretkey: string (secret reference)
  aiservice_s3_region: string (secret reference)
  
  # WatsonX Configuration
  aiservice_watsonxai_url: string
  aiservice_watsonxai_project_id: string (secret reference)
  aiservice_watsonxai_apikey: string (secret reference)
  aiservice_watsonxai_on_prem: string
  aiservice_watsonxai_ca_crt: string (secret reference, optional)
  aiservice_watsonxai_instance_id: string
  aiservice_watsonxai_username: string
  aiservice_watsonxai_version: string
  aiservice_watsonxai_verify: string
  
  # Tenant Entitlement
  tenant_entitlement_type: string
  tenant_entitlement_start_date: string
  tenant_entitlement_end_date: string
  
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
