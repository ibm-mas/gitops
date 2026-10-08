NFD Operator
===============================================================================
Installs the Redhat Node Feature Discovery required for the nvidia gpu operator

<!--docs-include-start-->
## Overview

This chart installs the Node Feature Discovery (NFD) operator, which detects hardware features and capabilities on cluster nodes and exposes them as node labels for use by workload scheduling.



## Configuration

### Values

This chart uses default NFD operator settings. No additional configuration values are required for a standard installation.

## Examples

### Default NFD operator installation

```yaml
merge-key: "my-account/my-cluster"
# No additional values required.
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `openshift-nfd-group` | `openshift-nfd` | Always | `cluster_admin_role` |
| `Subscription` | `nfd-operator` | `openshift-nfd` | Always | `cluster_admin_role` |
| `NodeFeatureDiscovery` | `nfd-master-worker` | `openshift-nfd` | Always | `cluster_admin_role` |
| `ServiceAccount` | `postdelete-delete-csv-sa` | `openshift-nfd` | PostDelete hook | `cluster_admin_role` |
| `Role` | `postdelete-delete-csv-r` | `openshift-nfd` | PostDelete hook | `cluster_admin_role` |
| `RoleBinding` | `postdelete-delete-csv-rb` | `openshift-nfd` | PostDelete hook | `cluster_admin_role` |
| `Job` | `postdelete-delete-csv-job` | `openshift-nfd` | PostDelete hook | `cluster_admin_role` |
