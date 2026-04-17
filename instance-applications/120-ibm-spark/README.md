IBM Analytics Engine Powered by Apache Spark (Spark)
===============================================================================
Deploys and configures the CP4D Service, IBM Analytics Engine Powered by Apache Spark (Spark). Deploys the Spark operator and its dependencies.
Spark extends jupyter notebooks features inside Watson Studio notebooks which can be leveraged by Maximo Predict data sets.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Subscription` | Spark operator subscription | CP4D instance namespace | Always | `application_admin_role` |
| `AnalyticsEngine` | Spark service CR | CP4D instance namespace | Always | `application_admin_role` |
| `ServiceAccount` | Spark control-plane service account | CP4D instance namespace | When control-plane job is enabled | `application_admin_role` |
| `ClusterRole` | Spark control-plane cluster roles | N/A (cluster-scoped) | When control-plane job is enabled | `application_admin_role` |
| `ClusterRoleBinding` | Spark control-plane cluster role binding | N/A (cluster-scoped) | When control-plane job is enabled | `application_admin_role` |
| `Job` | Spark control-plane post-sync job | CP4D instance namespace | When control-plane job is enabled | `application_admin_role` |
