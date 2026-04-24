IBM Maximo Operator Catalog
===============================================================================
Installs the `ibm-operator-catalog` `CatalogSource` into the `openshift-marketplace` namespace

<!--docs-include-start-->

## Configuration

### Values

```yaml
ibm_operator_catalog:
  # MAS Operator Catalog version
  # Specifies which version of the IBM Maximo Application Suite operator catalog to use
  # Example: v8-230414-amd64, v9-260326-amd64
  # Default: v8-230414-amd64
  mas_catalog_version: v9-260326-amd64

  # MAS Operator Catalog image
  # Container image location for the operator catalog
  # Default: icr.io/cpopen/ibm-maximo-operator-catalog
  mas_catalog_image: icr.io/cpopen/ibm-maximo-operator-catalog

  # IBM Entitlement Key (required)
  # Your IBM entitlement key for accessing IBM container images
  # Can be obtained from https://myibm.ibm.com/products-services/containerlibrary
  ibm_entitlement_key: ""
```

## Base Cluster Values

This chart inherits common cluster configuration values. The most frequently used base values are:

```yaml
account:
  id: string                    # AWS account identifier

region:
  id: string                    # AWS region identifier

cluster:
  id: string                    # Unique cluster identifier
  url: string                   # OpenShift cluster API URL
  nonshared: boolean            # Whether cluster is dedicated (true) or shared (false)

sm:                             # Secrets Manager configuration
  aws_access_key_id: string (secret reference)
  aws_secret_access_key: string (secret reference)
```

For complete documentation of all base cluster values including optional fields like `notifications`, `custom_labels`, `devops`, and `cli_image_repo`, see the [Cluster Base Values Reference](../../docs/reference/cluster-base-values.md).

### Usage Examples

**Basic configuration with entitlement key:**
```yaml
ibm_operator_catalog:
  mas_catalog_version: v9-260326-amd64
  mas_catalog_image: icr.io/cpopen/ibm-maximo-operator-catalog
  ibm_entitlement_key: "your-entitlement-key-here"
```

**Using a specific catalog version:**
```yaml
ibm_operator_catalog:
  mas_catalog_version: v8-230414-amd64
  mas_catalog_image: icr.io/cpopen/ibm-maximo-operator-catalog
  ibm_entitlement_key: "your-entitlement-key-here"
```

**With custom catalog image registry:**
```yaml
ibm_operator_catalog:
  mas_catalog_version: v9-260326-amd64
  mas_catalog_image: my-registry.example.com/ibm-maximo-operator-catalog
  ibm_entitlement_key: "your-entitlement-key-here"
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ServiceAccount` | `default` | `openshift-marketplace` | Always | `cluster_admin_role` |
| `Secret` | `ibm-entitlement` | `openshift-marketplace` | Always | `cluster_admin_role` |
| `CatalogSource` | `ibm-operator-catalog` | `openshift-marketplace` | Always | `cluster_admin_role` |
