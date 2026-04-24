IBM Resource-Based Access Control (RBAC)
===============================================================================
Installs the IBM RBAC roles and role bindings. Groups are managed by the Group Sync Operator.

<!--docs-include-start-->


## Configuration

### Values

```yaml
ibm_rbac:
  # Group to ClusterRole bindings (required)
  # Maps OpenShift groups to ClusterRoles for IBM RBAC
  # Groups are typically synchronized from IBM Security Verify via Group Sync Operator
  # Format: List of binding configurations
  binding_to_group: []
    # Example structure:
    # - group: "mas-cluster-admins"
    #   clusterrole: "cluster-admin"
    # - group: "mas-sre-team"
    #   clusterrole: "sre-editor"
    # - group: "mas-dba-team"
    #   clusterrole: "dba"
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

**Basic IBM RBAC configuration:**
```yaml
ibm_rbac:
  binding_to_group:
    - group: "mas-cluster-admins"
      clusterrole: "cluster-admin"
    - group: "mas-sre-editors"
      clusterrole: "sre-editor"
    - group: "mas-sre-readers"
      clusterrole: "sre-reader"
```

**Complete IBM RBAC setup:**
```yaml
ibm_rbac:
  binding_to_group:
    - group: "mas-cluster-admins"
      clusterrole: "cluster-admin"
    - group: "mas-sre-editors"
      clusterrole: "sre-editor"
    - group: "mas-sre-readers"
      clusterrole: "sre-reader"
    - group: "mas-dba-editors"
      clusterrole: "dba-editor"
    - group: "mas-dba-readers"
      clusterrole: "dba-reader"
    - group: "mas-network-team"
      clusterrole: "network"
    - group: "mas-network-readers"
      clusterrole: "network-reader"
    - group: "mas-provisioning-team"
      clusterrole: "provisioning"
    - group: "mas-automation"
      clusterrole: "sre-automation-admin"
```

**Minimal configuration:**
```yaml
binding_to_group:
  - group: "platform-admins"
    clusterrole: "cluster-admin"
  - group: "platform-viewers"
    clusterrole: "view"
```

### IBM RBAC Roles

This chart creates the following custom ClusterRoles:

- **`dba`** - Database administrator role with permissions for DB2 and database operations
- **`dba-editor`** - DBA role with edit permissions
- **`dba-reader`** - DBA role with read-only permissions
- **`network`** - Network administrator role for network policy and ingress management
- **`network-reader`** - Network role with read-only permissions
- **`sre-editor`** - Site Reliability Engineer role with edit permissions
- **`sre-reader`** - SRE role with read-only permissions
- **`sre-automation-admin`** - Automation service account role with elevated permissions
- **`provisioning`** - Provisioning role for cluster resource management

### Prerequisites

- Group Sync Operator installed and configured
- Groups synchronized from IBM Security Verify or other identity provider
- Groups must exist in OpenShift before bindings are created

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ClusterRole` | `dba` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRole` | `network` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRole` | `sre-editor` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `cluster-admin` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `dba-editor` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `dba-reader` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `network-reader` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `network` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `provisioning` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `sre-automation-admin` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `sre-editor` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `sre-reader` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `Group` | OpenShift groups referenced by IBM RBAC bindings | N/A (cluster-scoped) | Always | `cluster_admin_role` |

**Note:** ClusterRoleBindings reference groups that are synchronized by the Group Sync Operator.
