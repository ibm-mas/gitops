IBM CommonServices Control (CS)
===============================================================================
Deploys and configures IBM CS Control that is required for IBM CPD

<!--docs-include-start-->


## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | IBM CS control operator group | CP4D operators namespace | Always | `application_admin_role` |
| `Subscription` | IBM licensing/operator subscription | CP4D operators namespace | Always | `application_admin_role` |
| `IBMLicensing` | IBM licensing instance | CP4D operators namespace | Always | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_cp4d:
  cpd_operators_namespace: string
  cpd_instance_namespace: string
  cpd_cs_control_namespace: string
  ibm_entitlement_key: string (secret reference)
  namespace_scope_channel: string (secret reference)
  namespace_scope_install_plan: string
  cpd_ibm_licensing_channel: string (secret reference)
  cpd_ibm_licensing_version: string (secret reference)
  cpd_licensing_install_plan: string
  cpfs_channel: string (secret reference)
  cpfs_size: string
  cpfs_install_plan: string
  cpd_scale_config: string
  cpd_admin_login_sa: string
  cpd_platform_channel: string (secret reference)
  cpd_platform_cr_name: string
  cpd_platform_install_plan: string
  cpd_product_version: string
  cpd_iam_integration: string
  cpd_primary_storage_class: string
  cpd_metadata_storage_class: string
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
