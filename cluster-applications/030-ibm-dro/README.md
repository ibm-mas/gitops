IBM DRO
===============================================================================
Deploy and configure DRO (Data Reporter Operator).

The `dro_cmm_setup` being set to true is used to configure connectivity to CMM which is an internal IBM tool, and is not required outside of IBM.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `ibm-mas-operator-group` | `ibm-software-central` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Secret` | `redhat-marketplace-pull-secret` | `ibm-software-central` | When `application_admin_role` is true | `application_admin_role` |
| `Subscription` | `ibm-metrics-operator` | `ibm-software-central` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Subscription` | `ibm-data-reporter-operator` | `ibm-software-central` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `MarketplaceConfig` | `marketplaceconfig` | `ibm-software-central` | When `application_admin_role` is true | `application_admin_role` |
| `ClusterRole` | DRO cluster roles | N/A (cluster-scoped) | When `cluster_admin_role` is true | `cluster_admin_role` |
| `ClusterRoleBinding` | `metric-state-view-binding` | N/A (cluster-scoped) | When `cluster_admin_role` is true | `cluster_admin_role` |
| `ClusterRoleBinding` | `reporter-cluster-monitoring-binding` | N/A (cluster-scoped) | When `cluster_admin_role` is true | `cluster_admin_role` |
| `ClusterRoleBinding` | `manager-cluster-monitoring-binding` | N/A (cluster-scoped) | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Certificate` | DRO certificate resources | `ibm-software-central` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `ClusterIssuer` | DRO cluster issuer resources | N/A (cluster-scoped) | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Secret` | `ibm-data-reporter-operator-api-token` | `ibm-software-central` | When `application_admin_role` is true | `application_admin_role` |
| `Secret` | `aws` | `ibm-software-central` | When `application_admin_role` and `run_sync_hooks` are true | `application_admin_role` |
| `ServiceAccount` | `postsync-ibm-dro-update-sm-sa` | `ibm-software-central` | When `application_admin_role` and `run_sync_hooks` are true | `application_admin_role` |
| `Role` | `postsync-ibm-dro-update-sm-r` | `ibm-software-central` | When `application_admin_role` and `run_sync_hooks` are true | `application_admin_role` |
| `RoleBinding` | `postsync-ibm-dro-update-sm-rb` | `ibm-software-central` | When `application_admin_role` and `run_sync_hooks` are true | `application_admin_role` |
| `Job` | `postsync-ibm-dro-update-sm-job-*` | `ibm-software-central` | When `application_admin_role` and `run_sync_hooks` are true | `application_admin_role` |
| `Secret` | `dest-header-map-secret` | `ibm-software-central` | When `cluster_admin_role` and `dro_cmm_setup` are true | `cluster_admin_role` |
| `Secret` | `auth-header-map-secret` | `ibm-software-central` | When `cluster_admin_role` and `dro_cmm_setup` are true | `cluster_admin_role` |
| `Secret` | `auth-body-data-secret` | `ibm-software-central` | When `cluster_admin_role` and `dro_cmm_setup` are true | `cluster_admin_role` |
| `ConfigMap` | `kazaam-configmap` | `ibm-software-central` | When `cluster_admin_role` and `dro_cmm_setup` are true | `cluster_admin_role` |
| `DataReporterConfig` | `datareporterconfig` | `ibm-software-central` | When `cluster_admin_role` and `dro_cmm_setup` are true | `cluster_admin_role` |