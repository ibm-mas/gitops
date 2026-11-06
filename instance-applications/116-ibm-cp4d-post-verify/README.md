---
IBM CP4D Post Verify
===============================================================================
Instantiated by the [`116-ibm-cp4d-post-verify-app.yaml`](https://github.com/ibm-mas/gitops/tree/main/root-applications/ibm-mas-instance-root/templates/116-ibm-cp4d-post-verify-app.yaml) root application.

<!--docs-include-start-->
## Overview

This chart verifies that the Cloud Pak for Data admin username, password and URL are available once the CPD platform has been installed. It is used for CPD 5.4.0 and above, where the platform is installed by the `cpd-platform` ArgoCD application (wave 115) rather than by a Job in the `110-ibm-cp4d` chart.

The Job waits (up to 60 minutes) for the `lite-cr` `ZenService` to publish its URL, then checks the admin credentials secret and prints the dashboard URL and admin username. It runs at sync-wave 116, before the CPD services at wave 120.

For CPD below 5.4.0 the equivalent Job is part of the [`110-ibm-cp4d`](../110-ibm-cp4d/README.md) chart.

## Examples

### Minimal configuration

```yaml
merge-key: "my-account/my-cluster"
ibm_cp4d:
  cpd_product_version: "5.4.0"
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ServiceAccount` | `cpd-post-verify-sa` | CP4D operators namespace | CPD 5.4.0 and above | `cluster_admin_role` |
| `Role` | `cpd-post-verify-role` | CP4D instance namespace | CPD 5.4.0 and above | `cluster_admin_role` |
| `RoleBinding` | `cpd-post-verify-rb` | CP4D instance namespace | CPD 5.4.0 and above | `cluster_admin_role` |
| `Job` | `cpd-post-verify-job-*` | CP4D operators namespace | CPD 5.4.0 and above | `cluster_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
cpd_instance_namespace: string
cpd_operators_namespace: string
cli_image_repo: string

custom_labels:
  key: value
```

**Note**: This chart does not use a top-level key wrapper.

### Key behaviors

- Rendered only for CPD 5.4.0 and above (the root application is gated on the CPD version).
- Waits for `ZenService/lite-cr` to report a URL before checking the admin credentials, instead of failing immediately.
- Uses a namespaced Role limited to `get` on the two admin credential secrets and on `lite-cr`.
- Uses a hashed Job name so ArgoCD can recreate the Job when immutable Job inputs change.

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

For complete documentation of all base instance values including optional fields like `custom_labels`, `devops`, `cli_image_repo`, `mas_wipe_mongo_data`, and ArgoCD-specific settings, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md).
