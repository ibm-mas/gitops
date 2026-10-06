IBM Watson Studio Local (WSL)
===============================================================================
Deploys and configures the CP4D Service, Watson Studio Local (WSL) needed for `MAS Predict`. Deploys WSL operator and its dependencies.

<!--docs-include-start-->


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

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_wsl:
  cpd_service_storage_class: string
  cpd_service_block_storage_class: string
  cpd_service_scale_config: string
  wsl_version: string (secret reference)
  wsl_channel: string (secret reference)
  ccs_version: string (secret reference)
  datarefinery_version: string (secret reference)
  ws_runtimes_version: string (secret reference)
  wsl_install_plan: string
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
