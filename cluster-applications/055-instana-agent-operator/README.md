Instana Agent Operator
===============================================================================
Installs the Instana Agent Operator. Additionally, a cron job is installed that 

<!--docs-include-start-->

is responsible for updating the Instana agent custom resource with the connection
information for each DB2 instance in the cluster.

## Configuration

### Values

```yaml
instana_agent_operator:
  # Enable Instana agent installation
  # Set to false to skip installation
  # Default: true
  install: true

  # Storage class for JKS (Java KeyStore) persistent volume
  # Used to store certificates and keys
  # Example: gp3, efs-sc
  jks_storage_class: ""

  # Instana agent key (required)
  # Your Instana agent key for authentication
  # Obtain from Instana backend
  key: ""

  # Instana endpoint host (required)
  # Hostname of your Instana backend
  # Example: ingress-red-saas.instana.io
  endpoint_host: ""

  # Instana endpoint port (required)
  # Port number for Instana backend connection
  # Default: 443
  endpoint_port: "443"

  # Additional environment variables (optional)
  # Custom environment variables for the Instana agent
  env: {}
    # Example:
    # INSTANA_AGENT_ZONE: "production"
    # INSTANA_AGENT_TAGS: "cluster:mas-prod,env:production"
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

**Basic Instana agent installation:**
```yaml
instana_agent_operator:
  install: true
  jks_storage_class: "gp3"
  key: "your-instana-agent-key"
  endpoint_host: "ingress-red-saas.instana.io"
  endpoint_port: "443"
```

**With custom environment variables:**
```yaml
instana_agent_operator:
  install: true
  jks_storage_class: "gp3"
  key: "your-instana-agent-key"
  endpoint_host: "ingress-red-saas.instana.io"
  endpoint_port: "443"
  env:
    INSTANA_AGENT_ZONE: "production"
    INSTANA_AGENT_TAGS: "cluster:mas-prod,env:production,owner:platform-team"
    INSTANA_AGENT_MODE: "APM"
```

**With custom endpoint port:**
```yaml
instana_agent_operator:
  install: true
  jks_storage_class: "efs-sc"
  key: "your-instana-agent-key"
  endpoint_host: "instana.example.com"
  endpoint_port: "8443"
```

### Prerequisites

- Instana backend instance with agent key
- Storage class available for persistent volumes
- Network connectivity to Instana backend endpoint

### DB2 Integration

This chart includes a CronJob that automatically discovers DB2 instances in the cluster and updates the InstanaAgent configuration with their connection details. This enables automatic monitoring of DB2 databases without manual configuration.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `instana-agent` | `instana-agent` | Always | `cluster_admin_role` |
| `Subscription` | `instana-agent` | `instana-agent` | Always | `cluster_admin_role` |
| `InstanaAgent` | `instana-agent` | `instana-agent` | Always | `cluster_admin_role` |
| `PersistentVolumeClaim` | `instana-agent` | `instana-agent` | Always | `cluster_admin_role` |
| `Secret` | `instana-agent-key` | `instana-agent` | Always | `cluster_admin_role` |
| `Secret` | `db2-passwords` | `instana-agent` | Always | `cluster_admin_role` |
| `ClusterRole` | `instana-agent-db2-config-role` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ServiceAccount` | `instana-agent-db2-config-sa` | `instana-agent` | Always | `cluster_admin_role` |
| `Role` | `instana-agent-db2-config-role` | `instana-agent` | Always | `cluster_admin_role` |
| `RoleBinding` | `instana-agent-db2-config-role` | `instana-agent` | Always | `cluster_admin_role` |
| `RoleBinding` | `instana-agent-db2-config-sa-edit` | `instana-agent` | Always | `cluster_admin_role` |
| `NetworkPolicy` | `instana-agent-db2-config-netpol` | `instana-agent` | Always | `cluster_admin_role` |
| `CronJob` | `instana-agent-db2-config` | `instana-agent` | Always | `cluster_admin_role` |

**Note:** The CronJob automatically updates the InstanaAgent configuration with DB2 instance connection details.
