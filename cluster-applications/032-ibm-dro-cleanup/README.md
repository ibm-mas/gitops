IBM DRO Cleanup
===============================================================================
Contains a PostDelete hook that issues deletes for MarketplaceConfig CRs to allow ibm-dro application uninstall to proceed.

<!--docs-include-start-->
## Overview

This chart provides a PostDelete hook that deletes `MarketplaceConfig` CRs so the IBM DRO application can uninstall cleanly. It must be managed by an ArgoCD Application in a later sync-wave than `030-ibm-dro`.


This chart must be managed by an Application in a later syncwave than ibm-dro to ensure the PostDelete hook can
complete before the ibm dro application is removed (otherwise the pods responsible for managing the MarketplaceConfig
finalizers will be removed before they get a chance to complete).

## Configuration

### Values

This chart has no configurable values. It automatically handles cleanup of MarketplaceConfig resources during DRO application deletion via a PostDelete hook.

The cleanup job runs in the same namespace as the DRO installation (`ibm-software-central` by default).

## Examples

### Enabling DRO cleanup

This chart requires no configuration values:

```yaml
merge-key: "my-account/my-cluster"
# No additional values required — cleanup is automatic on deletion.
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | `placeholder` | `ibm-software-central` | Always | `cluster_admin_role` |
| `Job` | `postdelete-delete-marketplaceconfigs-job` | `ibm-software-central` | PostDelete hook only | `cluster_admin_role` |

**Note:** The PostDelete Job is only created during application deletion to clean up MarketplaceConfig resources.
