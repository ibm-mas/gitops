IBM DRO
===============================================================================
Deploy and configure DRO (Data Reporter Operator).

The `dro_cmm_setup` being set to true is used to configure connectivity to CMM which is an internal IBM tool, and is not required outside of IBM.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `ibm-mas-operator-group` | `ibm-software-central` | Always | `cluster_admin_role` |
| `Secret` | `ibm-entitlement` | `ibm-software-central` | Always | `cluster_admin_role` |
| `Subscription` | `ibm-metrics-operator` | `ibm-software-central` | Always | `cluster_admin_role` |
| `Subscription` | `redhat-marketplace-operator` | `ibm-software-central` | Always | `cluster_admin_role` |
| `MarketplaceConfig` | `marketplaceconfig` | `ibm-software-central` | Always | `cluster_admin_role` |
| `ClusterRole` | `dro-cluster-role` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `dro-cluster-role-binding` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `Secret` | `dro-api-token` | `ibm-software-central` | Always | `cluster_admin_role` |
| `Job` | `postsync-dro-update-sm-job-*` | `default` | When `run_sync_hooks` is true | `cluster_admin_role` |
| `Secret` | `dest-header-map-secret` | `ibm-software-central` | When `dro_cmm_setup` is true | `cluster_admin_role` |
| `Secret` | `dest-api-key-secret` | `ibm-software-central` | When `dro_cmm_setup` is true | `cluster_admin_role` |
| `ConfigMap` | `dest-ca-certificate-config` | `ibm-software-central` | When `dro_cmm_setup` is true | `cluster_admin_role` |
| `DataReporterConfig` | `datareporterconfig` | `ibm-software-central` | When `dro_cmm_setup` is true | `cluster_admin_role` |