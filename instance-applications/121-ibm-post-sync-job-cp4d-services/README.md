IBM Post Sync Job CP4D Services
===============================================================================
Instantiated by the [`121-ibm-post-sync-job-cp4d-services.yaml`](https://github.com/ibm-mas/gitops/tree/main/root-applications/ibm-mas-instance-root/templates/121-ibm-post-sync-job-cp4d-services.yaml) root application.

<!--docs-include-start-->


Defines a post-sync Job used to perform CP4D service follow-up operations after selected CP4D services such as Watson Studio Local (WSL), Watson Machine Learning (WML), or SPSS Modeler are installed.

The chart creates namespaced RBAC and a Job in the CP4D operators namespace. The Job waits for CP4D service resources to become ready and applies any required post-install adjustments.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ServiceAccount` | `cpd-service-postsync-sa` | CP4D operators namespace | When at least one of `wml_channel`, `wsl_channel`, or `spss_channel` is set | `cluster_admin_role` |
| `Role` | `cpd-service-postsync-instance-role` | CP4D instance namespace | When at least one of `wml_channel`, `wsl_channel`, or `spss_channel` is set | `cluster_admin_role` |
| `Role` | `cpd-service-postsync-operators-role` | CP4D operators namespace | When at least one of `wml_channel`, `wsl_channel`, or `spss_channel` is set | `cluster_admin_role` |
| `RoleBinding` | `cpd-service-postsync-instance-rb` | CP4D instance namespace | When at least one of `wml_channel`, `wsl_channel`, or `spss_channel` is set | `cluster_admin_role` |
| `RoleBinding` | `cpd-service-postsync-operators-rb` | CP4D operators namespace | When at least one of `wml_channel`, `wsl_channel`, or `spss_channel` is set | `cluster_admin_role` |
| `Job` | `cpd-services-post-sync-job-*` | CP4D operators namespace | When at least one of `wml_channel`, `wsl_channel`, or `spss_channel` is set | `cluster_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
cpd_product_version: string
cpd_instance_namespace: string
cpd_operators_namespace: string
cpd_service_storage_class: string
cpd_service_block_storage_class: string
cpd_service_scale_config: string
cli_image_repo: string

wml_channel: string
wsl_channel: string
spss_channel: string

custom_labels:
  key: value

junitreporter:
  reporter_name: string
  cluster_id: string
  instance_id: string
  devops_mongo_uri: string
  devops_build_number: string
  gitops_version: string
  cli_image_repo: string

mas_wipe_mongo_data: boolean
```

**Note**: This chart does not use a top-level key wrapper.

### Key behaviors

- Runs only when at least one CP4D service channel is configured.
- Grants the Job access to patch CP4D service resources in the instance namespace and operator deployments in the operators namespace.
- Uses a hashed Job name so ArgoCD can recreate the Job when immutable Job inputs change.
- Applies post-install adjustments for CP4D services using the IBM MAS CLI image.

## Base Instance Values

This chart inherits common instance configuration values. The most frequently used base values are:

```yaml
account:
  id: string                    # Account identifier

region:
  id: string                    # Region identifier

cluster:
  id: string                    # Cluster identifier
  url: string                   # OpenShift cluster API URL

instance:
  id: string                    # MAS instance identifier
```

For complete documentation of all base instance values including optional fields like `custom_labels`, `devops`, `cli_image_repo`, `mas_wipe_mongo_data`, and ArgoCD-specific settings, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md).