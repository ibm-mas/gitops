IBM CIS Compliance Cleanup
===============================================================================
Contains a PostDelete hook that issues deletes for ProfileBundle CRs to allow cis-compliance operator uninstall to proceed.

<!--docs-include-start-->
## Overview

This chart provides a PostDelete hook that deletes `ProfileBundle` CRs so the CIS Compliance operator can uninstall cleanly. It must be managed by an ArgoCD Application in a later sync-wave than `040-cis-compliance` to ensure finalizers are cleared before operator pods are removed.


This chart must be managed by an Application in a later syncwave than cis-compliance to ensure the PostDelete hook can
complete before the cis-compliance operator is removed (otherwise the pods responsible for managing the ProfileBundle
finalizers will be removed before they get a chance to complete).

## Configuration

### Values

This chart has no configurable values. It automatically handles cleanup of ProfileBundle resources during CIS Compliance operator deletion via a PostDelete hook.

The cleanup job runs in the `openshift-compliance` namespace.

## Examples

### Enabling CIS compliance cleanup

This chart requires no configuration values. It is enabled automatically when the parent `040-cis-compliance` application is present:

```yaml
merge-key: "my-account/my-cluster"
# No additional values required — cleanup is automatic on deletion.
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | `placeholder` | `openshift-compliance` | Always | `cluster_admin_role` |
| `Job` | `postdelete-delete-profilebundles-job` | `openshift-compliance` | PostDelete hook only | `cluster_admin_role` |

**Note:** The PostDelete Job is only created during application deletion to clean up ProfileBundle resources.
