NFD Operator
===============================================================================
Installs the Redhat Node Feature Discovery required for the nvidia gpu operator

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `openshift-nfd-group` | `openshift-nfd` | Always | `cluster_admin_role` |
| `Subscription` | `nfd-operator` | `openshift-nfd` | Always | `cluster_admin_role` |
| `NodeFeatureDiscovery` | `nfd-master-worker` | `openshift-nfd` | Always | `cluster_admin_role` |