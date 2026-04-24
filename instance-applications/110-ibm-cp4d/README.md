IBM Cloud Pak for Data (CP4D)
===============================================================================
Deploys and configures CP4D needed for `MAS Assist` and `MAS Predict`. Deploys the CP4D platform operator and its dependencies.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | `ibm-entitlement-key` | CP4D instance namespace | Always | `cluster_admin_role` |
| `ServiceAccount` | CP4D service accounts | CP4D instance namespace | Always and hook-driven as applicable | `cluster_admin_role` |
| `Role` | CP4D namespace roles | CP4D instance namespace | Always | `cluster_admin_role` |
| `RoleBinding` | CP4D namespace role bindings | CP4D instance namespace | Always | `cluster_admin_role` |
| `ClusterRole` | CP4D cluster roles | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | CP4D cluster role bindings | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `Job` | CP4D install and verification jobs | CP4D operators namespace | Version-dependent and always for verification hooks as applicable | `cluster_admin_role` |
| `Ibmcpd` | CP4D platform custom resource | CP4D instance namespace | Always | `cluster_admin_role` |
| `ConfigMap` | CP4D service dependency config maps | CP4D operators namespace | When optional services are enabled | `cluster_admin_role` |
| `Subscription` | CP4D service subscriptions | CP4D operators namespace | When optional services are enabled | `cluster_admin_role` |
| `OperandRegistry` | CP4D operand registries | CP4D operators namespace | When WSL or SPSS services are enabled | `cluster_admin_role` |
| `OperandConfig` | CP4D operand configs | CP4D operators namespace | When WSL or SPSS services are enabled | `cluster_admin_role` |
