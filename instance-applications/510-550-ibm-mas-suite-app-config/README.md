MAS Application Configuration
===============================================================================
Generic chart for configuring a workspace for a MAS application (a.k.a "activating" the MAS application).

<!--docs-include-start-->

Certain templates are enabled only for specific MAS applications (`mas_app_id`).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `StorageClass` | Application configuration storage classes | Application namespace / cluster | When required by the target MAS app | `application_admin_role` |
| `ConfigMap` | Placeholder, sanity/verify scripts, and runtime config maps | Application namespace | When required by the target MAS app | `application_admin_role` |
| `Secret` | Application-specific configuration secrets | Application namespace | When required by the target MAS app | `application_admin_role` |
| `NetworkPolicy` | Post-sync and recurring job network policies | Application namespace | When associated jobs are enabled | `application_admin_role` |
| `ServiceAccount` | Post-sync and recurring job service accounts | Application namespace | When associated jobs are enabled | `application_admin_role` |
| `Role` | Post-sync and recurring job roles | Application namespace | When associated jobs are enabled | `application_admin_role` |
| `RoleBinding` | Post-sync and recurring job role bindings | Application namespace | When associated jobs are enabled | `application_admin_role` |
| `ClusterRole` | Verify job cluster roles | N/A (cluster-scoped) | When cluster-level verification is enabled | `application_admin_role` |
| `ClusterRoleBinding` | Verify job cluster role bindings | N/A (cluster-scoped) | When cluster-level verification is enabled | `application_admin_role` |
| `CronJob` | Recurring update/app-role cron jobs | Application namespace | When associated recurring jobs are enabled | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
mas_app_id: string
mas_app_namespace: string
mas_app_ws_apiversion: string
mas_app_ws_kind: string
mas_workspace_id: string

# Server Bundles Configuration (optional)
# Application-specific server bundle configuration

# Customization Archives (optional)
customization_archive_secret_names:
  - secret_name: string
    password: string (secret reference)
    username: string (secret reference)

# Manage Logging Configuration (optional)
manage_logging_secret_name: string
manage_logging_access_secret_key: string (secret reference)

# Global Secrets (optional)
# Application-specific global secrets configuration

# Update Schedule (optional)
manage_update_schedule: string

# Facilities Configuration (optional)
facilities_vault_secret_name: string
facilities_vault_secret_value: string (secret reference)
facilities_liberty_extensions_secret_name: string
facilities_liberty_extensions_b64_secret_value: string (secret reference)

# Application Workspace Specification
# Application-specific workspace configuration varies by MAS app

# Certificate Management
mas_manual_cert_mgmt: boolean
run_sanity_test: boolean
public_tls_secret_name: string (optional)
ca_cert: string (optional)
tls_cert: string (optional)
tls_key: string (optional)

# Storage Configuration (optional)
storage_class_definitions:
  key: value
```

**Note**: Values marked with "(secret reference)" should use the format `<path:secrets/path:key>` to reference secrets stored in the Secrets Vault. This chart does not use a top-level key wrapper. Configuration varies significantly by MAS application.

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
