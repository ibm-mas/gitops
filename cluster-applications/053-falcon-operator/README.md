CrowdStrike Falcon Operator
===============================================================================
Installs the CrowdStrike Falcon Operator for node monitoring. See https://github.com/CrowdStrike/falcon-operator

<!--docs-include-start-->


## Configuration

### Values

```yaml
falcon_operator:
  # CrowdStrike Falcon OAuth2 client ID (required)
  # Obtain from CrowdStrike Falcon console
  client_id: ""

  # CrowdStrike Falcon OAuth2 client secret (required)
  # Obtain from CrowdStrike Falcon console
  client_secret: ""

  # CrowdStrike cloud region (optional)
  # Specify the cloud region for your Falcon instance
  # Options: us-1, us-2, eu-1, us-gov-1
  # If not specified, defaults to us-1
  cloud_region: ""

  # Node sensor configuration (optional)
  # Advanced configuration for the FalconNodeSensor resource
  # Allows customization of sensor behavior and resource limits
  node_sensor: {}
    # Example configuration:
    # falcon:
    #   tags:
    #     - "environment:production"
    #     - "cluster:mas-prod"
    # node:
    #   resources:
    #     limits:
    #       cpu: "1000m"
    #       memory: "512Mi"
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

**Basic Falcon operator installation:**
```yaml
falcon_operator:
  client_id: "your-falcon-client-id"
  client_secret: "your-falcon-client-secret"
```

**With specific cloud region:**
```yaml
falcon_operator:
  client_id: "your-falcon-client-id"
  client_secret: "your-falcon-client-secret"
  cloud_region: "eu-1"
```

**With custom node sensor configuration:**
```yaml
falcon_operator:
  client_id: "your-falcon-client-id"
  client_secret: "your-falcon-client-secret"
  cloud_region: "us-1"
  node_sensor:
    falcon:
      tags:
        - "environment:production"
        - "cluster:mas-prod"
        - "owner:platform-team"
    node:
      resources:
        limits:
          cpu: "1000m"
          memory: "512Mi"
        requests:
          cpu: "500m"
          memory: "256Mi"
```

### Prerequisites

- CrowdStrike Falcon account with API credentials
- OAuth2 API client created in Falcon console with appropriate permissions
- Sufficient cluster resources for sensor deployment on all nodes

For more information, see the [CrowdStrike Falcon Operator documentation](https://github.com/CrowdStrike/falcon-operator).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `falcon-operator` | `falcon-operator` | Always | `cluster_admin_role` |
| `Subscription` | `falcon-operator` | `falcon-operator` | Always | `cluster_admin_role` |
| `FalconNodeSensor` | `falcon-node-sensor` | `falcon-operator` | Always | `cluster_admin_role` |
