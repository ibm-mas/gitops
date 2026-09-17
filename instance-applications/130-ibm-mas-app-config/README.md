App Configuration for MAS Core Platform
===============================================================================
Create a AppCfg CR instance and associated credentials secret for use by MAS.

<!--docs-include-start-->

## Overview

This chart provisions an `AppCfg` CR for a MAS application, enabling persistent volume configuration and Mobile Application Framework (MAF) settings. It also contains a post-delete hook (`postdelete-delete-cr.yaml`) that will ensure the config CR is deleted when the ArgoCD application managing this chart is deleted (this will not happen by default as the config CR is asserted to be owned by the `Suite` CR by the MAS entity managers).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `AppCfg` | MAS application configuration CR | MAS core namespace | Always | `application_admin_role` |
| `Job` | Post-delete app configuration cleanup job | MAS core namespace | When `use_postdelete_hooks` is enabled | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
mas_config_name: string
mas_config_chart: string
mas_config_scope: string
mas_workspace_id: string
mas_application_id: string
mas_config_kind: string
mas_config_api_version: string
use_postdelete_hooks: boolean

system_appcfg_labels:
  mas.ibm.com/configScope: string
  mas.ibm.com/instanceId: string

maf_enabled: boolean

persistentVolume:
  name: string
  size: string
  storageClassName: string

# Pod Templates (optional)
mas_appcfg_pod_templates:
  key: value
```

**Note**: This chart does not use a top-level key wrapper.

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

## Examples

### System-scoped AppCfg with Persistent Volume

```yaml
# appcfg-params.yaml
merge-key: "production/us-east-1/inst1"
mas_config_name: "inst1-appconfig"
mas_config_chart: "ibm-mas-app-config"
mas_config_scope: "system"
mas_config_kind: "AppCfg"
mas_config_api_version: "config.mas.ibm.com/v1"
use_postdelete_hooks: true

system_appcfg_labels:
  mas.ibm.com/configScope: "system"
  mas.ibm.com/instanceId: "inst1"

maf_enabled: true

persistentVolume:
  name: "appconfig-pv"
  size: "20Gi"
  storageClassName: "ocs-storagecluster-cephfs"
```

### Workspace-scoped AppCfg

```yaml
merge-key: "production/us-east-1/inst1"
mas_config_name: "inst1-ws1-appconfig"
mas_config_chart: "ibm-mas-app-config"
mas_config_scope: "workspace"
mas_workspace_id: "ws1"
mas_application_id: "manage"
mas_config_kind: "AppCfg"
mas_config_api_version: "config.mas.ibm.com/v1"
use_postdelete_hooks: false

maf_enabled: false

persistentVolume:
  name: "appconfig-ws1-pv"
  size: "10Gi"
  storageClassName: "ocs-storagecluster-cephfs"
```

## Prerequisites

- MAS Suite CR deployed and healthy in the target namespace
- Persistent storage class available in the cluster (e.g., `ocs-storagecluster-cephfs`)
- `application_admin_role` service account with sufficient RBAC permissions

## Troubleshooting

### AppCfg CR Not Reconciling

Check the CR status and MAS entity manager logs:
```bash
oc get appcfg -n mas-<instance_id>-core
oc describe appcfg <mas_config_name> -n mas-<instance_id>-core
oc logs -n mas-<instance_id>-core -l app.kubernetes.io/component=entitymgr --tail=100
```

### Post-delete Job Failing

Verify the service account and role bindings used by the post-delete hook exist:
```bash
oc get sa postdelete-delete-cr-sa -n mas-<instance_id>-core
oc get rolebinding postdelete-delete-cr-rb -n mas-<instance_id>-core
```

## Related Documentation

- [MAS Suite Chart](../130-ibm-mas-suite/README.md)
- [Instance Base Values Reference](../../docs/reference/instance-base-values.md)
- [Configuration Repository](../../docs/configrepo.md)
