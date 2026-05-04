IBM Cloud Pak for Data Operator (CPD)
===============================================================================
Deploys and configures CPD Platform Operator

<!--docs-include-start-->


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

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_cp4d:
  cpd_operators_namespace: string
  cpd_instance_namespace: string
  cpd_cs_control_namespace: string
  ibm_entitlement_key: string (secret reference)
  namespace_scope_channel: string (secret reference)
  namespace_scope_install_plan: string
  cpd_ibm_licensing_channel: string (secret reference)
  cpd_ibm_licensing_version: string (secret reference)
  cpd_licensing_install_plan: string
  cpfs_channel: string (secret reference)
  cpfs_size: string
  cpfs_install_plan: string
  cpd_scale_config: string
  cpd_admin_login_sa: string
  cpd_platform_channel: string (secret reference)
  cpd_platform_cr_name: string
  cpd_platform_install_plan: string
  cpd_product_version: string
  cpd_iam_integration: string
  cpd_primary_storage_class: string
  cpd_metadata_storage_class: string
```

**Note**: Values marked with "(secret reference)" should use the format `<path:secrets/path:key>` to reference secrets stored in the Secrets Vault.

## Base Instance Values

This chart inherits common instance configuration values. The most frequently used base values are:

```yaml
account:
  id: string                    # Account identifier
  name: string                  # Account name

region:
  id: string                    # Region identifier
  name: string                  # Region name

cluster:
  id: string                    # Cluster identifier
  name: string                  # Cluster name

instance:
  id: string                    # MAS instance identifier

sm:                             # Secrets Manager configuration
  aws_secret_region: string
  aws_access_key_id: string (secret reference)
  aws_secret_access_key: string (secret reference)
```

For complete documentation of all base instance values including optional fields like `custom_labels`, `argocluster_instance`, `application_admin_service_account`, `mas_wipe_mongo_data`, `allow_list`, `additional_vpn`, `application_configuration`, `use_postdelete_hooks`, `additional_resources`, `extensions`, `enhanced_dr`, and `cli_image_repo`, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md).
