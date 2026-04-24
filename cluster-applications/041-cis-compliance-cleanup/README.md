IBM CIS Compliance Cleanup
===============================================================================
Contains a PostDelete hook that issues deletes for ProfileBundle CRs to allow cis-compliance operator uninstall to proceed.
This chart must be managed by an Application in a later syncwave than cis-compliance to ensure the PostDelete hook can
complete before the cis-compliance operator is removed (otherwise the pods responsible for managing the ProfileBundle
finalizers will be removed before they get a chance to complete).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | `placeholder` | `openshift-compliance` | Always | `cluster_admin_role` |
| `Job` | `postdelete-delete-profilebundles-job` | `openshift-compliance` | PostDelete hook only | `cluster_admin_role` |

**Note:** The PostDelete Job is only created during application deletion to clean up ProfileBundle resources.