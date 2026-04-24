IBM Analytics Engine Powered by Apache Spark (Spark)
===============================================================================
Deploys and configures the CP4D Service, IBM Analytics Engine Powered by Apache Spark (Spark). Deploys the Spark operator and its dependencies.

<!--docs-include-start-->

Spark extends jupyter notebooks features inside Watson Studio notebooks which can be leveraged by Maximo Predict data sets.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Subscription` | Spark operator subscription | CP4D instance namespace | Always | `application_admin_role` |
| `AnalyticsEngine` | Spark service CR | CP4D instance namespace | Always | `application_admin_role` |
| `ServiceAccount` | Spark control-plane service account | CP4D instance namespace | When control-plane job is enabled | `application_admin_role` |
| `ClusterRole` | Spark control-plane cluster roles | N/A (cluster-scoped) | When control-plane job is enabled | `application_admin_role` |
| `ClusterRoleBinding` | Spark control-plane cluster role binding | N/A (cluster-scoped) | When control-plane job is enabled | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_spark:
  ccs_version: string (secret reference)
  cpd_service_block_storage_class: string
  cpd_service_scale_config: string
  cpd_service_storage_class: string
  spark_channel: string (secret reference)
  spark_version: string (secret reference)
  spark_install_plan: string
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
