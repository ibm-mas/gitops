IBM MAS Post Sync Jobs
===============================================================================
Instantiated by the /gitops/root-applications/ibm-mas-instance-root/templates/600-ibm-post-sync-jobs.yaml root application.

<!--docs-include-start-->


Defines Jobs to perform various tasks that need to happen after MAS applications are installed and ready.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | Initial user/bootstrap runtime secret | MAS core namespace | Always | `application_admin_role` |
| `NetworkPolicy` | Initial user creation network policy | MAS core namespace | Always | `application_admin_role` |
| `ServiceAccount` | Initial user creation service account | MAS core namespace | Always | `application_admin_role` |
| `Role` | Initial user creation roles | MAS core namespace | Always | `application_admin_role` |
| `RoleBinding` | Initial user creation role bindings | MAS core namespace | Always | `application_admin_role` |
| `Job` | Initial user creation post-sync job | MAS core namespace | Always | `application_admin_role` |

## Configuration

This chart does not accept additional configuration values beyond the base instance values.

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
  backend: string               # Secrets manager backend type: "aws" (default) or "kubernetes"
  secret_keys_seperator: string # Override the key separator used when constructing secret names.
                                # Defaults to "/" for aws backend, "_" for kubernetes backend.
```

For complete documentation of all base instance values including optional fields like `custom_labels`, `argocluster_instance`, `application_admin_service_account`, `mas_wipe_mongo_data`, `allow_list`, `additional_vpn`, `application_configuration`, `use_postdelete_hooks`, `additional_resources`, `extensions`, `enhanced_dr`, and `cli_image_repo`, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md).
