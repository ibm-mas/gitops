WatsonStudio Configuration for MAS Core Platform
===============================================================================
Create a WatsonStudioCfg CR instance and associated credentials secret for use by MAS.

<!--docs-include-start-->


## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | Watson Studio credential secret | MAS core namespace | Always | `application_admin_role` |
| `WatsonStudioCfg` | Watson Studio configuration CR | MAS core namespace | Always | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
mas_config_chart: string
mas_config_name: string
mas_config_scope: string
mas_workspace_id: string
mas_application_id: string
mas_config_kind: string
mas_config_api_version: string
use_postdelete_hooks: boolean

suite_watson_studio_secret_name: string

suite_wscfg_labels:
  mas.ibm.com/applicationId: string
  mas.ibm.com/configScope: string
  mas.ibm.com/instanceId: string
  mas.ibm.com/workspaceId: string

suite_watson_studio_username: string (secret reference)
suite_watson_studio_password: string (secret reference)

watson_studio_config:
  config:
    credentials:
      secretName: string
    endpoint: string (secret reference)
  displayName: string
  type: string
```

**Note**: Values marked with "(secret reference)" should use the format `<path:secrets/path:key>` to reference secrets stored in the Secrets Vault. This chart does not use a top-level key wrapper.

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
