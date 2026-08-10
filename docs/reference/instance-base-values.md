# Instance Base Values Reference

All instance-application charts inherit common configuration values from the base instance template. These values provide essential information about the deployment environment, credentials, and common settings.

## Configuration

Instance applications accept the following base configuration values:

```yaml
# Account Information
account:
  id: string                                    # Unique account identifier
  name: string                                  # Human-readable account name

# Region Information
region:
  id: string                                    # Region identifier (e.g., us-east-1)
  name: string                                  # Human-readable region name

# Cluster Information
cluster:
  id: string                                    # Unique cluster identifier
  name: string                                  # Human-readable cluster name

# Instance Information
instance:
  id: string                                    # MAS instance identifier (3-12 characters)

# Secrets Manager Configuration
sm:
  aws_secret_region: string                     # AWS region where secrets are stored
  aws_access_key_id: string                     # AWS access key (secret reference)
  aws_secret_access_key: string                 # AWS secret key (secret reference)

# Custom Labels (optional)
custom_labels:
  key: value                                    # Custom label key-value pairs

# ArgoCD Configuration
argocluster_instance:
  name: string                                  # ArgoCD cluster name (typically "in-cluster")

# Application Admin
application_admin_service_account: string       # Service account for admin operations

# MongoDB Management
mas_wipe_mongo_data: boolean                    # WARNING: true will delete all MongoDB data

# Network Access Control (optional)
allow_list: string                              # Comma-separated CIDR blocks

# VPN Configuration (optional)
additional_vpn: string                          # VPN configuration

# Application Configuration (optional)
application_configuration:
  key: value                                    # Application-specific settings

# Lifecycle Hooks
use_postdelete_hooks: boolean                   # Enable post-delete cleanup hooks

# Additional Resources (optional)
additional_resources:
  key: value                                    # Additional Kubernetes resources

# Extensions (optional)
extensions:
  key: value                                    # Extension configurations

# Disaster Recovery (optional)
enhanced_dr:
  enabled: boolean                              # Enable enhanced DR features

# CLI Image
cli_image_repo: string                          # Container image repository for CLI tools
```

**Secret Reference Format:** Use `<path:secrets/path:key>` to reference secrets stored in AWS Secrets Manager.
