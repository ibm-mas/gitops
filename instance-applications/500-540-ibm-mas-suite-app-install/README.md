MAS Application Install
===============================================================================
Generic chart for installing a MAS Application.

<!--docs-include-start-->

Certain templates are enabled only for specific MAS editions (`mas_edition`) and/or applications (`mas_app_id`).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `StorageClass` | Application-specific storage classes | Application namespace / cluster | When required by the target MAS app | `application_admin_role` |
| `ConfigMap` | Placeholder and JVM/custom config maps | Application namespace | When required by the target MAS app | `application_admin_role` |
| `NetworkPolicy` | Pre/post-sync SCC job network policies | Application namespace | When sync hook jobs are enabled | `application_admin_role` |
| `ServiceAccount` | Pre/post-sync SCC job service accounts | Application namespace | When sync hook jobs are enabled | `application_admin_role` |
| `ClusterRole` | SCC management cluster roles | N/A (cluster-scoped) | When sync hook jobs are enabled | `application_admin_role` |
| `ClusterRoleBinding` | SCC management cluster role bindings | N/A (cluster-scoped) | When sync hook jobs are enabled | `application_admin_role` |
| `Secret` | Entitlement and suite certificate secrets | Application namespace | When required by the target MAS app | `application_admin_role` |
| `OperatorGroup` | MAS application operator group | Application namespace | When required by the target MAS app | `application_admin_role` |
| `ResourceQuota` | MVI resource quota | Application namespace | When required by the target MAS app | `application_admin_role` |
| `Subscription` | MAS application operator subscription | Application namespace | When required by the target MAS app | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_suite_app_{mas_app_id}_install:
  ibm_entitlement_key: string (secret reference)
  mas_instance_id: string
  mas_app_id: string
  mas_app_install_plan: string
  mas_edition: string
  mas_app_namespace: string
  mas_app_channel: string
  mas_app_catalog_source: string
  mas_app_api_version: string
  mas_app_kind: string
  run_sync_hooks: boolean
  
  # Application Specification (optional)
  # Application-specific configuration varies by MAS app
  
  # Certificate Management
  mas_manual_cert_mgmt: boolean
  public_tls_secret_name: string (optional)
  ca_cert: string (optional)
  tls_cert: string (optional)
  tls_key: string (optional)
  
  # GPU Configuration (optional)
  gpu_request_quota: string
  
  # Storage Configuration (optional)
  storage_class_definitions:
    key: value
```

**Note**: Values marked with "(secret reference)" should use the format `<path:secrets/path:key>` to reference secrets stored in the Secrets Vault. The top-level key uses the pattern `ibm_suite_app_{mas_app_id}_install` where `{mas_app_id}` is replaced with the actual application ID (e.g., `manage`, `monitor`, `predict`).

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
