IBM Sync Jobs CP4D
===============================================================================
Instantiated by the [`101-ibm-sync-jobs-cp4d.yaml`](https://github.com/ibm-mas/gitops/tree/main/root-applications/ibm-mas-instance-root/templates/101-ibm-sync-jobs-cp4d.yaml) root application.

<!--docs-include-start-->


Defines prerequisite catalog sources and a presync Job used to prepare Cloud Pak for Data (CP4D) dependencies before CP4D resources are installed for a MAS instance.

The chart creates version-specific `CatalogSource` resources in the CP4D operators namespace and runs a presync Job that gathers operator dependency channel and version information for later use.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `CatalogSource` | `cpd-platform` | CP4D operators namespace | When `cpd_product_version` is set | `cluster_admin_role` |
| `CatalogSource` | `opencloud-operators` | CP4D operators namespace | When `cpd_product_version` is set | `cluster_admin_role` |
| `CatalogSource` | `ibm-zen-operator-catalog` | CP4D operators namespace | For CP4D versions that require it | `cluster_admin_role` |
| `ServiceAccount` | `presync-cpd-olm-sa` | `mas-<instance_id>-syncres` | When `cpd_product_version` is set | `cluster_admin_role` |
| `Role` | `presync-cpd-olm-role-syncres-<instance_id>` | `mas-<instance_id>-syncres` | When `cpd_product_version` is set | `cluster_admin_role` |
| `RoleBinding` | `presync-cpd-olm-rb-syncres-<instance_id>` | `mas-<instance_id>-syncres` | When `cpd_product_version` is set | `cluster_admin_role` |
| `Role` | `presync-cpd-olm-role-operators-<instance_id>` | CP4D operators namespace | When `cpd_product_version` is set | `cluster_admin_role` |
| `RoleBinding` | `presync-cpd-olm-rb-operators-<instance_id>` | CP4D operators namespace | When `cpd_product_version` is set | `cluster_admin_role` |
| `Job` | `presync-cpd-olm-job-*` | `mas-<instance_id>-syncres` | When `cpd_product_version` is set | `cluster_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
account_id: string
region_id: string
cluster_id: string
instance_id: string
cli_image_repo: string
cpd_product_version: string
cpd_operators_namespace: string
sm_aws_access_key_id: string
sm_aws_secret_access_key: string

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

- Creates CP4D catalog sources based on the selected `cpd_product_version`.
- Reads package and release metadata from the cluster to determine dependency channels and versions.
- Uses a hashed Job name so ArgoCD can recreate the Job safely when immutable Job inputs change.
- Uses the shared sync resources namespace `mas-<instance_id>-syncres` for the presync Job and supporting RBAC.

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

sm:
  aws_access_key_id: string (secret reference)
  aws_secret_access_key: string (secret reference)
```

For complete documentation of all base instance values including optional fields like `custom_labels`, `devops`, `cli_image_repo`, `mas_wipe_mongo_data`, and ArgoCD-specific settings, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md).