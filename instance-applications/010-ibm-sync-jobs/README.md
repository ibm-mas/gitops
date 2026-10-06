IBM MAS Sync Jobs
===============================================================================
Instantiated by the /gitops/root-applications/ibm-mas-instance-root/templates/91-ibm-sync-jobs.yaml root application.

<!--docs-include-start-->


Defines Jobs to perform various tasks that need to happen before ibm-sls and the suite are installed, and after they are removed. It also performs various tasks for CP4D when it is set to be installed or upgraded.

Supporting resources are defined in the 90-ibm-sync-resources chart which is managed by an application with a lower syncwave (90).
This is to ensure that these resources perist long enough for any PostDelete hooks in this chart to complete.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | `placeholder` | Instance-specific namespace | Always | `application_admin_role` |
| `Job` | AWS DocDB add/remove user jobs | Instance-specific namespaces | When DocDB integration is configured | `application_admin_role` |
| `Job` | IBM MAS suite cert sync job | Instance-specific namespace | When suite certificate sync is enabled | `application_admin_role` |

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
