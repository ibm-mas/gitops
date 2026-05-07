# Cluster Base Values Reference

All cluster-application charts inherit common configuration values from the base cluster template. These values provide essential information about the deployment environment, credentials, and common settings.

## Configuration

Cluster applications accept the following base configuration values:

```yaml
# Account Information
account:
  id: string                                    # Unique AWS account identifier

# Region Information
region:
  id: string                                    # AWS region identifier (e.g., us-east-1)

# Cluster Information
cluster:
  id: string                                    # Unique cluster identifier
  url: string                                   # OpenShift cluster API URL
  nonshared: boolean                            # true = dedicated, false = shared multi-tenant

# Secrets Manager Configuration
sm:
  aws_access_key_id: string                     # AWS access key (secret reference)
  aws_secret_access_key: string                 # AWS secret key (secret reference)

# Notification Configuration (optional)
notifications:
  slack_channel_id: string                      # Slack channel ID for notifications

# Custom Labels (optional)
custom_labels:
  key: value                                    # Custom label key-value pairs

# DevOps Integration (optional)
devops:
  mongo_uri: string                             # MongoDB connection string for metrics
  build_number: string                          # Build number for tracking

# CLI Image
cli_image_repo: string                          # Container image repository for CLI tools
```

**Secret Reference Format:** Use `<path:secrets/path:key>` to reference secrets stored in AWS Secrets Manager.
