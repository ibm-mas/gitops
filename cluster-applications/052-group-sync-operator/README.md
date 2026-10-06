Group Sync Operator
===============================================================================
Installs the Group Sync Operator. Minimum required version: 0.0.31

<!--docs-include-start-->


## Configuration

### Values

```yaml
group_sync_operator:
  # Cron schedule for group synchronization
  # How often to sync groups from IBM Security Verify
  # Default: */30 * * * * (every 30 minutes)
  # Format: standard cron expression
  cron_schedule: "*/30 * * * *"

  # IBM Security Verify tenant URL (required)
  # The base URL of your IBM Security Verify tenant
  # Example: https://your-tenant.verify.ibm.com
  isv_tenant_url: ""

  # IBM Security Verify client ID (required)
  # OAuth client ID for API access
  isv_client_id: ""

  # IBM Security Verify client secret (required)
  # OAuth client secret for API access
  isv_client_secret: ""

  # List of groups to synchronize (required)
  # Array of group names or patterns to sync from IBM Security Verify
  # Example: ["mas-admins", "mas-users", "mas-developers"]
  isv_groups: []
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

**Basic group sync configuration:**
```yaml
group_sync_operator:
  cron_schedule: "*/30 * * * *"
  isv_tenant_url: "https://my-company.verify.ibm.com"
  isv_client_id: "your-client-id"
  isv_client_secret: "your-client-secret"
  isv_groups:
    - "mas-admins"
    - "mas-users"
```

**Hourly synchronization:**
```yaml
group_sync_operator:
  cron_schedule: "0 * * * *"  # Every hour at minute 0
  isv_tenant_url: "https://my-company.verify.ibm.com"
  isv_client_id: "your-client-id"
  isv_client_secret: "your-client-secret"
  isv_groups:
    - "cluster-admins"
    - "developers"
    - "operators"
```

**Multiple groups with frequent sync:**
```yaml
group_sync_operator:
  cron_schedule: "*/15 * * * *"  # Every 15 minutes
  isv_tenant_url: "https://my-company.verify.ibm.com"
  isv_client_id: "your-client-id"
  isv_client_secret: "your-client-secret"
  isv_groups:
    - "mas-admins"
    - "mas-users"
    - "mas-developers"
    - "mas-operators"
  - "mas-viewers"
```

### Prerequisites

- IBM Security Verify tenant with configured groups
- OAuth application credentials (client ID and secret) with group read permissions
- Group Sync Operator version 0.0.31 or higher

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `group-sync-operator` | `group-sync-operator` | Always | `cluster_admin_role` |
| `Subscription` | `group-sync-operator` | `group-sync-operator` | Always | `cluster_admin_role` |
| `Secret` | `isv-group-sync` | `group-sync-operator` | Always | `cluster_admin_role` |
| `GroupSync` | `isv-group-sync` | `group-sync-operator` | Always | `cluster_admin_role` |

**Note:** The GroupSync resource synchronizes groups from IBM Security Verify based on the configured schedule.
