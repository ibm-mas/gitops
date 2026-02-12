IBM Maximo Operator Catalog
===============================================================================
Installs the `ibm-operator-catalog` `CatalogSource` into the `openshift-marketplace` namespace

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ServiceAccount` | `default` | `openshift-marketplace` | Always | `cluster_admin_role` |
| `Secret` | `ibm-entitlement` | `openshift-marketplace` | Always | `cluster_admin_role` |
| `CatalogSource` | `ibm-operator-catalog` | `openshift-marketplace` | Always | `cluster_admin_role` |
