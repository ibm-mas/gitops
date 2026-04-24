IBM Cloud Pak for Data Operator (CPD)
===============================================================================
Deploys and configures CPD Platform Operator

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | `ibm-entitlement-key` | CP4D operators namespace | Always | `cluster_admin_role` |
| `ServiceAccount` | CP4D operator service accounts | CP4D operators namespace | Always | `cluster_admin_role` |
| `Role` | CP4D operator namespace roles | CP4D operators namespace and `openshift-marketplace` | Always | `cluster_admin_role` |
| `RoleBinding` | CP4D operator namespace role bindings | CP4D operators namespace | Always | `cluster_admin_role` |
| `ClusterRole` | CP4D operator cluster roles | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | CP4D operator cluster role bindings | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `OperatorGroup` | `common-service` | CP4D operators namespace | Always | `cluster_admin_role` |
| `Subscription` | CP4D and prerequisite operator subscriptions | CP4D operators namespace | Always | `cluster_admin_role` |
| `NamespaceScope` | `cpd-operators` | CP4D operators namespace | Always | `cluster_admin_role` |
| `Job` | CP4D prerequisite and upgrade cleanup jobs | CP4D operators namespace | Always | `cluster_admin_role` |
| `ConfigMap` | `common-service-maps` | `kube-public` | Always | `cluster_admin_role` |
