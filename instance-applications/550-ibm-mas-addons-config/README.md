MAS Addons Configuration
===============================================================================
Instantiated by the [`550-ibm-mas-addons-config.yaml`](https://github.com/ibm-mas/gitops/tree/main/root-applications/ibm-mas-instance-root/templates/550-ibm-mas-addons-config.yaml) root application.

<!--docs-include-start-->
## Overview

This chart applies add-on configuration to IBM MAS applications, enabling optional feature modules and integration settings beyond the base application installation.



Creates MAS add-on configuration custom resources for optional platform capabilities such as allow lists, additional VPN configuration, enhanced disaster recovery, extensions, replica databases, nonshared cluster settings, application configuration, additional resources, and production database access.

This chart includes two hook Jobs that handle GenericAddon CR lifecycle:

- **PreSync hook** — runs on every sync. Compares the set of GenericAddon CRs that should exist (based on current values) against what is present in the namespace, and deletes any CR that is no longer desired. This handles the case where an addon is disabled on a live instance (e.g. `cluster_nonshared` set to `false`) — ArgoCD would otherwise stop managing the CR without deleting it, leaving it drifting in the cluster.

- **PostDelete hook** — runs when the entire ArgoCD application is deleted (i.e. full instance deprovision). Deletes all remaining `GenericAddon` CRs in the namespace so their operator-set finalizers are cleared before the Suite operator is torn down.

## Examples

### Minimal configuration

```yaml
merge-key: "my-account/my-cluster"
ibm_mas_addons_config:
  mas_instance_id: inst1
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `GenericAddon` | `<instance_id>-addons-allowlist` | `mas-<instance_id>-core` | When `allow_list` is set | `application_admin_role` |
| `GenericAddon` | `<instance_id>-addons-additional-vpn` | `mas-<instance_id>-core` | When `additional_vpn` is enabled | `application_admin_role` |
| `GenericAddon` | `<instance_id>-addons-enhanced-dr` | `mas-<instance_id>-core` | When `enhanced_dr` is enabled | `application_admin_role` |
| `GenericAddon` | `<instance_id>-addons-extensions` | `mas-<instance_id>-core` | When `extensions` is enabled | `application_admin_role` |
| `GenericAddon` | `<instance_id>-addons-replica-db` | `mas-<instance_id>-core` | When eligible replica database settings are present | `application_admin_role` |
| `GenericAddon` | `<instance_id>-addons-nonshared-cluster` | `mas-<instance_id>-core` | When `cluster_nonshared` is enabled | `application_admin_role` |
| `GenericAddon` | `<instance_id>-addons-application-configuration` | `mas-<instance_id>-core` | When `application_configuration` is enabled | `application_admin_role` |
| `GenericAddon` | `<instance_id>-addons-additional-resources` | `mas-<instance_id>-core` | When `additional_resources` is provided | `application_admin_role` |
| `GenericAddon` | `<instance_id>-addons-production-db-access` | `mas-<instance_id>-core` | When supported production database access settings are present | `application_admin_role` |
| `Job` | `presync-delete-disabled-addons-<hash>` | `mas-<instance_id>-core` | When `use_postdelete_hooks` and `application_admin_role` are true | `application_admin_role` |
| `Job` | `postdelete-delete-genericaddons-<hash>` | `mas-<instance_id>-core` | When `use_postdelete_hooks` and `application_admin_role` are true | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
allow_list: string
enhanced_dr: boolean
extensions: boolean
additional_vpn: boolean
cluster_nonshared: boolean
application_configuration: boolean
use_postdelete_hooks: boolean
cli_image_repo: string

additional_resources:
  instances:
    - name: string
      cost: string
      reasonCode: string

databases:
  - mas_application_id: string
    replica_db: boolean

production_database_access:
  type: string

custom_labels:
  key: value

junitreporter:
  reporter_name: string
  cluster_id: string
  instance_id: string
  devops_mongo_uri: string
  devops_build_number: string
  gitops_version: string
  cli_image_repo: string
```

**Note**: This chart does not use a top-level key wrapper.

### Key behaviors

- Creates one or more `GenericAddon` custom resources in the MAS core namespace based on enabled features.
- Uses `mas.ibm.com/configScope` and `mas.ibm.com/instanceId` labels on generated add-on resources.
- Supports post-delete cleanup through a `PostDelete` ArgoCD hook Job when `use_postdelete_hooks` is enabled.
- Relies on supporting post-delete resources created elsewhere in the MAS suite lifecycle.

## Base Instance Values

This chart inherits common instance configuration values. The most frequently used base values are:

```yaml
account:
  id: string                    # Account identifier

region:
  id: string                    # Region identifier

cluster:
  id: string                    # Cluster identifier
  url: string                   # OpenShift cluster API URL

instance:
  id: string                    # MAS instance identifier
```

For complete documentation of all base instance values including optional fields like `custom_labels`, `cli_image_repo`, `allow_list`, `additional_vpn`, `application_configuration`, `use_postdelete_hooks`, `additional_resources`, `extensions`, and `enhanced_dr`, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md).