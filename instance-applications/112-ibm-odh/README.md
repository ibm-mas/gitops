IBM ODH
===============================================================================
Deploy and configure ODH with configurable version

<!--docs-include-start-->

## Migration to RHOAI

**Note**: OpenDataHub (ODH) is being replaced by Red Hat OpenShift AI (RHOAI). To migrate to RHOAI, see the [RHOAI Migration Guide](../116-ibm-rhoai/README.md#migration-from-odh-to-rhoai).

Shared resources (aiservice namespace, ServiceMesh, Authorino, Serverless operators, and NetworkPolicies) have ArgoCD protection annotations that prevent deletion during ODH uninstallation, ensuring a safe migration path to RHOAI.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Namespace` | ODH and serverless namespaces | ODH-related namespaces | Always | `application_admin_role` |
| `OperatorGroup` | ODH operator groups | ODH-related namespaces | Always | `application_admin_role` |
| `Subscription` | ODH/operator subscriptions | ODH-related namespaces | Always | `application_admin_role` |
| `ServiceAccount` | ODH service mesh service account | ODH-related namespaces | Always | `application_admin_role` |
| `DSCInitialization` | ODH DSC initialization CR | ODH namespace | Always | `application_admin_role` |
| `DataScienceCluster` | ODH data science cluster CR | ODH namespace | Always | `application_admin_role` |
| `PeerAuthentication` | Istio peer authentication for ODH | ODH namespace | Always | `application_admin_role` |
| `DestinationRule` | Istio destination rule for ODH | ODH namespace | Always | `application_admin_role` |
| `NetworkPolicy` | ODH network policy | ODH namespace | Always | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_odh:
  install: string                    # Set to "true" to enable ODH installation
  openshift_namespace: string
  odh_pipeline_channel: string
  odh_pipeline_installplan: string
  pipeline_catalog_source: string
  service_mesh_namespace: string
  service_mesh_channel: string
  service_mesh_catalog_source: string
  service_mesh_sourceNamespace: string
  operatorName: string
  serverless_channel: string
  authorino_catalog_source: string
  odh_channel: string
  odh_catalog_source: string
  odh_operator_version: string
  odh_namespace: string
  
  aiservice_namespace: string
  pull_secret_name: string (secret reference)
  
  # Serverless Operator
  serverless_namespace: string
  serverless_operator_name: string
  serverless_operator_source: string
  serverless_operator_sourceNamespace: string
  
  # OpenDataHub Operator
  opendatahub_OperatorGroup_name: string
  opendatahub_name: string
  opendatahub_namespace: string
  opendatahub_installPlanApproval: string
  opendatahub_channel: string
  opendatahub_source: string
  opendatahub_sourceNamespace: string
  aiservice_odh_model_deployment_type: string
  primary_storage_class: string
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
