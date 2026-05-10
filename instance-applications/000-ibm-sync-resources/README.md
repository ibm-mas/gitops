IBM MAS Sync Resources
===============================================================================
Instantiated by the /gitops/root-applications/ibm-mas-instance-root/templates/90-ibm-sync-resources.yaml root application.

<!--docs-include-start-->


Various resources required to run Jobs contained in the 91-ibm-sync-jobs chart.
This application has a lower syncwave (90) than that of the 91-ibm-sync-jobs application responsible for running the jobs.
This is to ensure that the resources to persist long enough for the PostDelete hooks in that 91-ibm-sync-jobs to complete,
while still being cleaned up successfully when MAS instance is deprovisioned.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | AWS/IBM Suite shared credential secrets | Instance-specific namespaces | Always | `application_admin_role` |
| `ServiceAccount` | Sync resource job service accounts | Instance-specific namespaces | Always | `application_admin_role` |
| `Role` | Sync resource job roles | Instance-specific namespaces | Always | `application_admin_role` |
| `RoleBinding` | Sync resource job role bindings | Instance-specific namespaces | Always | `application_admin_role` |
| `ClusterRole` | IBM Suite DNS/cert sync cluster roles | N/A (cluster-scoped) | Always | `application_admin_role` |
| `ClusterRoleBinding` | IBM Suite DNS/cert sync cluster role bindings | N/A (cluster-scoped) | Always | `application_admin_role` |
| `NetworkPolicy` | Sync resource job network policy | Instance-specific namespaces | Always | `application_admin_role` |

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
```

For complete documentation of all base instance values including optional fields like `custom_labels`, `argocluster_instance`, `application_admin_service_account`, `mas_wipe_mongo_data`, `allow_list`, `additional_vpn`, `application_configuration`, `use_postdelete_hooks`, `additional_resources`, `extensions`, `enhanced_dr`, and `cli_image_repo`, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md).

