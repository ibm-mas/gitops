MAS Core Platform workspace
===============================================================================
Installs the workspace needed for the `Suite`.

<!--docs-include-start-->


## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Workspace` | MAS workspace CR | MAS core namespace | Always | `application_admin_role` |
| `NetworkPolicy` | Post-sync workspace label job network policy | MAS core namespace | When post-sync job is enabled | `application_admin_role` |
| `ServiceAccount` | Post-sync workspace label service account | MAS core namespace | When post-sync job is enabled | `application_admin_role` |
| `Role` | Post-sync workspace label roles | MAS core namespace | When post-sync job is enabled | `application_admin_role` |
| `RoleBinding` | Post-sync workspace label role binding | MAS core namespace | When post-sync job is enabled | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
mas_workspace_id: string
mas_workspace_name: string
allow_list: string (optional)
```

**Note**: This chart does not use a top-level key wrapper. Values are specified at the root level.

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
