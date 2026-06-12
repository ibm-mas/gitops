IBM RHOAI (Red Hat OpenShift AI)
===============================================================================
Deploy and configure Red Hat OpenShift AI with configurable version

<!--docs-include-start-->

## Migration from ODH to RHOAI

To migrate from OpenDataHub (ODH) to Red Hat OpenShift AI (RHOAI):

1. **Disable ODH**: Set `ibm_odh.install: "false"` in your configuration
2. **Sync with Prune**: Sync the ODH application in ArgoCD with the prune option enabled
3. **Wait for Uninstallation**: Wait for ODH resources to be removed (shared resources like namespaces, operators, and NetworkPolicies are protected and will not be deleted)
4. **Enable RHOAI**: Set `ibm_rhoai.install: "true"` in your configuration
5. **Sync RHOAI**: Sync the RHOAI application in ArgoCD

**Note**: The migration is safe because shared resources (aiservice namespace, ServiceMesh, Authorino, Serverless operators, and NetworkPolicies) have ArgoCD protection annotations (`Prune=false,Delete=false`) that prevent deletion during ODH uninstallation. RHOAI will reuse these existing resources.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Namespace` | RHOAI and serverless namespaces | RHOAI-related namespaces | Always | `application_admin_role` |
| `OperatorGroup` | RHOAI operator groups | RHOAI-related namespaces | Always | `application_admin_role` |
| `Subscription` | RHOAI/operator subscriptions | RHOAI-related namespaces | Always | `application_admin_role` |
| `ServiceAccount` | RHOAI service mesh service account | RHOAI-related namespaces | Always | `application_admin_role` |
| `DSCInitialization` | RHOAI DSC initialization CR | RHOAI namespace | Always | `application_admin_role` |
| `DataScienceCluster` | RHOAI data science cluster CR | RHOAI namespace | Always | `application_admin_role` |
| `PeerAuthentication` | Istio peer authentication for RHOAI | RHOAI namespace | Always | `application_admin_role` |
| `DestinationRule` | Istio destination rule for RHOAI | RHOAI namespace | Always | `application_admin_role` |
| `NetworkPolicy` | RHOAI network policy | RHOAI namespace | Always | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_rhoai:
  install: string                    # Set to "true" to enable RHOAI installation
  openshift_namespace: string
  rhoai_pipeline_name: string
  rhoai_pipeline_namespace: string
  rhoai_pipeline_operatorName: string
  rhoai_pipeline_source: string
  rhoai_pipeline_sourceNamespace: string
  serverless_namespace: string
  serverless_operator_name: string
  serverless_operator_source: string
  serverless_operator_sourceNamespace: string
  rhoai_OperatorGroup_name: string
  rhoai_name: string
  rhoai_channel: string
  rhoai_namespace: string
  rhoai_applications_namespace: string
  rhoai_monitoring_namespace: string
  rhoai_installPlanApproval: string
  rhoai_source: string
  rhoai_sourceNamespace: string
  rhoai_pipeline_channel: string
  rhoai_pipeline_installplan: string
  service_mesh_namespace: string
  service_mesh_channel: string
  service_mesh_catalog_source: string
  serverless_channel: string
  authorino_catalog_source: string
  rhoai_catalog_source: string
  rhoai_operator_version: string
  
  aiservice_namespace: string
  pull_secret_name: string (secret reference)
  
  mas_aiservice_storage_provider: string
  mas_aiservice_storage_accesskey: string (secret reference)
  mas_aiservice_storage_secretkey: string (secret reference)
  mas_aiservice_storage_host: string
  mas_aiservice_storage_port: string
  mas_aiservice_storage_ssl: string
  mas_aiservice_storage_region: string
  mas_aiservice_storage_pipelines_bucket: string
  primary_storage_class: string
  aiservice_rhoai_model_deployment_type: string
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
