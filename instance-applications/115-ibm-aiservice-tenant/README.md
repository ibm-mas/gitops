IBM AISERVICE Tenant
===============================================================================
Deploy and configure aiservice tenant with configurable version

<!--docs-include-start-->

## Overview

This chart provisions a tenant for Maximo AI Service. It installs the AI Service tenant operator and creates a tenant custom resource with all necessary configurations including SLS licensing, DRO integration, WatsonX connectivity, and optional tenant-specific scheduling configurations.

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


## Examples

### Basic Tenant Configuration

```yaml
# aiservice-tenant-params.yaml
merge-key: "production/us-west-2/aiservice-inst-1/tenants/tenant-01"
ibm_aiservice_tenant:
  tenant_id: "tenant-01"
  aiservice_namespace: "aiservice-inst-1-aiservice"
  aiservice_instance_id: "aiservice-inst-1"
  tenantNamespace: "aiservice-tenant-01"
  catalog_channel: "9.2.x"
  catalog_source: "ibm-operator-catalog"
  
  mas_icr_cp: "cp.icr.io/cp"
  mas_icr_cpopen: "icr.io/cpopen"
  
  # DRO Configuration
  dro_url: "<path:secret#dro_url>"
  dro_ca_b64enc: "<path:secret#dro_ca>"
  dro_api_token: "<path:secret#dro_token>"
  
  # SLS Configuration
  slscfg_ca_b64enc: "<path:secret#sls_slscfg_ca_b64encca>"
  slscfg_url: "<path:secret#sls_url>"
  slscfg_registration_key: "<path:secret#slscfg_registration_key>"
  aiservice_sls_subscription_id: "001"
  
  # RSL Configuration
  rsl_url: "rsl_url"
  rsl_org_id: "<path:secret#rsl_org_id>"
  rsl_token: "<path:secret#rsl_token>"
  rsl_ca_crt: "<path:secret#rsl_ca>"

  # S3 Configuration for Manage Job
  aiservice_s3_accesskey: "<path:secret#s3_accesskey>"
  aiservice_s3_secretkey: "<path:secret#s3_secretkey>"
  aiservice_s3_region: "<path:secret#s3_region>"
  
  # WatsonX Configuration
  aiservice_watsonxai_url: "https://us-south.ml.cloud.ibm.com"
  aiservice_watsonxai_project_id: "<path:secret#wx_project_id>"
  aiservice_watsonxai_apikey: "<path:secret#wx_apikey>"
  aiservice_watsonxai_on_prem: "false"
  
  # Tenant Entitlement
  tenant_entitlement_type: "standard"
  tenant_entitlement_start_date: "2025-01-01"
  tenant_entitlement_end_date: "2026-12-31"
  
  aiservice_operator_log_level: "2"
```

### Tenant with Custom Scheduling (9.2.x+)

```yaml
ibm_aiservice_tenant:
  # Specify all parameters as per above example
  
  # Tenant Scheduling Configuration
  tenant_scheduling_config:
    pipeline:
      nodeSelector:
        aiservice: pipeline
      tolerations:
        - effect: NoSchedule
          key: aiservice
          operator: Equal
          value: pipeline
    predictor:
      nodeSelector:
        aiservice: inference
      tolerations:
        - effect: NoSchedule
          key: aiservice
          operator: Equal
          value: inference
```


## Prerequisites

- AI Service instance deployed and running
- IBM Operator Catalog installed
- Suite License Service (SLS) or RSL configured
- DRO (Dynamic Resource Orchestrator) configured
- WatsonX instance accessible
- Sufficient cluster resources for tenant workloads

## Troubleshooting

### Tenant Operator Not Installing

Check the subscription and operator group:
```bash
oc get subscription ibm-aiservice-tenant -n <tenant-namespace>
oc get operatorgroup -n <tenant-namespace>
oc describe subscription ibm-aiservice-tenant -n <tenant-namespace>
```

### Tenant CR Not Reconciling

Check the tenant custom resource status:
```bash
oc get aiservicetenant -n <tenant-namespace>
oc describe aiservicetenant <tenant-id> -n <tenant-namespace>
oc logs -n <tenant-namespace> -l control-plane=ibm-aiservice --tail=100
```

## Related Documentation

- [AI Service Tenant Root Application](../../root-applications/ibm-aiservice-tenant-root/README.md)
- [AI Service Chart](../113-ibm-aiservice/README.md)
- [AI Service Instance Root Application](../../root-applications/ibm-aiservice-instance-root/README.md)
- [Instance Base Values Reference](../../docs/reference/instance-base-values.md)
- [Configuration Repository](../../docs/configrepo.md)
