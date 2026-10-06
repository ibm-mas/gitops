IBM DB2U Database
===============================================================================
Create a Db2RDS database for a MAS app.

<!--docs-include-start-->


## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | RDS setup and backup script config maps | Application namespace | Always | `application_admin_role` |
| `Secret` | RDS post-sync generated secret | Application namespace | When post-sync setup runs | `application_admin_role` |
| `Job` | RDS post-sync setup job | Application namespace | Always | `application_admin_role` |
| `CronJob` | RDS backup cron jobs | Application namespace | When backups are enabled | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
db2_namespace: string
mas_application_id: string
db2_instance_name: string
host: string (secret reference)
port: string (secret reference)
dbname: string (secret reference)
rds_admin_db_name: string (secret reference)
user: string (secret reference)
password: string (secret reference)
jdbc_connection_url: string (secret reference)
jdbc_connection_url_additional_params: string (optional)
replica_db: string

# Database Configuration (optional)
db2_database_db_config:
  key: value

# Backup Configuration (optional)
backup:
  enabled: boolean
  s3_bucket_name: string
  s3_prefix: string
  compression: string
  util_impact_priority: number
  num_files: number
  parallelism: number
  num_buffers: number
  full:
    enabled: boolean
    schedule: string (cron format)
```

**Note**: Values marked with "(secret reference)" should use the format `<path:secrets/path:key>` to reference secrets stored in the Secrets Vault.

## Base Instance Values

This chart inherits common instance configuration values. The most frequently used base values are:

```yaml
account:
  id: string                    # Account identifier
  name: string                  # Account name

region:
  id: string                    # Region identifier
  name: string                  # Region name

cluster:
  id: string                    # Cluster identifier
  name: string                  # Cluster name

instance:
  id: string                    # MAS instance identifier

sm:                             # Secrets Manager configuration
  aws_secret_region: string
  aws_access_key_id: string (secret reference)
  aws_secret_access_key: string (secret reference)
```

For complete documentation of all base instance values including optional fields like `custom_labels`, `argocluster_instance`, `application_admin_service_account`, `mas_wipe_mongo_data`, `allow_list`, `additional_vpn`, `application_configuration`, `use_postdelete_hooks`, `additional_resources`, `extensions`, `enhanced_dr`, and `cli_image_repo`, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md).
