# IBM DB2 RDS Database Configuration

This Helm chart configures and initializes IBM DB2 RDS databases for MAS applications.

## Overview

The chart performs the following operations:
1. Creates bufferpools and tablespaces for MAS applications (Manage, Facilities, IoT)
2. Applies DB2 instance registry settings
3. Applies DB2 database configuration parameters
4. Applies DB2 instance DBM configuration
5. Configures DB2 audit settings (optional)

## Configuration Values

### Basic Connection Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `rds_admin_db_name` | RDS admin database name | `"rdsadmin"` |
| `host` | Database host endpoint | `"xyz.db"` |
| `port` | Database port | `50000` |
| `dbname` | Target database name | `"rds1"` |
| `user` | Database username | `"dummy"` |
| `password` | Database password | `"dummy"` |

### Additional Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `db2_namespace` | DB2 namespace identifier | `""` |
| `mas_application_id` | MAS application ID (manage, facilities, iot) | `""` |
| `jdbc_connection_url` | JDBC connection URL | `""` |
| `replica_db` | Whether this is a replica database | `false` |

### MAS Application-Specific Configuration

The `mas_application_id` field determines which bufferpools, tablespaces, and configurations are created:

#### Manage
- **Bufferpools**: MAXBUFPOOL, MAXBUFPOOLINDX, MAXTEMPBP
- **Tablespaces**: MAXDATA, MAXINDEX, MAXTEMP
- **Recommended Settings**:
  - `DB2_WORKLOAD=MAXIMO`
  - `AUTO_MAINT=OFF`
  - `AUTO_TBL_MAINT=OFF`
  - `LOCKTIMEOUT=300`
  - `DATABASE_MEMORY=2199408 AUTOMATIC`

#### Facilities (TRIRIGA)
- **Bufferpools**: TRIBUFPOOL, TRIBUFPOOLINDEX, TRITEMPBP, DEDICATEDBPDATA, DEDICATEDBPINDX, DEDICATEDBPLOB
- **Tablespaces**: TRIDATA_DATA, TRIDATA_INDX, TRITEMP (temp), DEDICATED_DATA, DEDICATED_INDEX, DEDICATED_LOBS
- **Recommended Settings**:
  - `DB2_COMPATIBILITY_VECTOR=ORA`
  - `DB2_PARALLEL_IO=*`
  - `DB2_DEFERRED_PREPARE_SEMANTICS=YES`
  - `CATALOGCACHE_SZ=2048`
  - `LOCKTIMEOUT=30`

#### IoT
- **Bufferpools**: Uses default bufferpools
- **Tablespaces**: Uses default tablespaces
- **Recommended Settings**: Default DB2 settings with auto-maintenance enabled

### DB2 Instance Registry Configuration

Configure DB2 instance registry variables. Example:

```yaml
db2_instance_registry:
  DB2_COMPATIBILITY_VECTOR: "ORA"
  DB2_PARALLEL_IO: "*"
  DB2_DEFERRED_PREPARE_SEMANTICS: "YES"
  DB2_WORKLOAD: "MAXIMO"
  DB2_SKIPINSERTED: "ON"
  DB2AUTH: "OSAUTHDB,ALLOW_LOCAL_FALLBACK,PLUGIN_AUTO_RELOAD"
```

### DB2 Database Configuration

Configure database-level parameters. Example:

```yaml
db2_database_db_config:
  AUTO_MAINT: "OFF"
  AUTO_TBL_MAINT: "OFF"
  CATALOGCACHE_SZ: "800"
  LOCKTIMEOUT: "300"
  LOGSECOND: "100"
  STMTHEAP: "20000 AUTOMATIC"
  DATABASE_MEMORY: "2199408 AUTOMATIC"
```

### DB2 Instance DBM Configuration

Configure instance-level DBM parameters. Example:

```yaml
db2_instance_dbm_config:
  AGENT_STACK_SZ: "1024"
  RQRIOBLK: "65535"
  DFT_MON_STMT: "ON"
  MON_HEAP_SZ: "AUTOMATIC"
```

### DB2 Audit Configuration

Configure audit settings. Example:

```yaml
db2_addons_audit_config:
  enableAudit: true
  applyDefaultPolicy: true
```

### Backup Configuration

Configure automated backups to S3 for RDS DB2 databases. The backup system supports both full and incremental backups with configurable schedules.

#### Common Backup Parameters

These parameters are shared by both full and incremental backups:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backup.enabled` | Enable/disable backup cron jobs | `true` |
| `backup.s3_bucket_name` | S3 bucket name for backups | `""` (required) |
| `backup.s3_prefix` | S3 prefix/folder for backups | `"db2-backups"` |
| `backup.compression` | Compression option (INCLUDE/EXCLUDE) | `"INCLUDE"` |
| `backup.util_impact_priority` | Utility impact priority (1-100) | `50` |
| `backup.num_files` | Number of parallel backup files | `4` |
| `backup.parallelism` | Degree of parallelism | `4` |
| `backup.num_buffers` | Number of buffers | `8` |

#### Full Backup Configuration

Full backups run weekly on Sundays at 2 AM by default. Only schedule-specific parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backup.full.enabled` | Enable full backup cron job | `true` |
| `backup.full.schedule` | Cron schedule for full backup | `"0 2 * * 0"` (Sunday 2 AM) |

#### Incremental Backup Configuration

Incremental backups run daily at 2 AM except Sundays (Monday-Saturday). Only schedule-specific parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backup.incremental.enabled` | Enable incremental backup cron job | `true` |
| `backup.incremental.schedule` | Cron schedule for incremental backup | `"0 2 * * 1-6"` (Mon-Sat 2 AM) |

#### Backup Configuration Example

```yaml
backup:
  enabled: true
  s3_bucket_name: "my-db2-backups-bucket"
  s3_prefix: "prod/db2-backups"
  
  # Common parameters for both full and incremental backups
  compression: "INCLUDE"
  util_impact_priority: 50
  num_files: 4
  parallelism: 4
  num_buffers: 8
  
  # Full backup - only schedule-specific settings
  full:
    enabled: true
    schedule: "0 2 * * 0"  # Every Sunday at 2 AM
  
  # Incremental backup - only schedule-specific settings
  incremental:
    enabled: true
    schedule: "0 2 * * 1-6"  # Monday-Saturday at 2 AM
```

#### Backup Process Flow

The backup process follows these steps:

1. **Connect to rdsadmin database** - Establishes secure SSL connection
2. **Check VPC Gateway Endpoint for S3** - Verifies S3 connectivity (should be pre-configured)
3. **Configure S3 Integration** - Validates IAM roles and bucket permissions (should be pre-configured)
4. **Call rdsadmin.backup_database** - Initiates backup with parameters:
   - `database_name`: Target database
   - `s3_bucket_name`: S3 bucket for backup storage
   - `s3_prefix`: S3 path prefix (includes timestamp)
   - `backup_type`: FULL or INCREMENTAL
   - `compression_option`: INCLUDE or EXCLUDE
   - `util_impact_priority`: 1-100 (higher = more resources)
   - `num_files`: Number of parallel backup files
   - `parallelism`: Degree of parallelism
   - `num_buffers`: Number of buffers
5. **Monitor backup status** - Polls `rdsadmin.get_task_status` until completion
6. **Verify upload to S3** - Confirms backup files are uploaded
7. **Terminate connection** - Closes database connection

#### S3 Backup Structure

Backups are organized in S3 with the following structure:
```
s3://<bucket>/<prefix>/<database_name>/<backup_type>/<timestamp>/
```

Example:
```
s3://my-db2-backups-bucket/prod/db2-backups/MAXDB80/full/20260213_020000/
s3://my-db2-backups-bucket/prod/db2-backups/MAXDB80/incremental/20260214_020000/
```

#### Prerequisites for Backup

1. **VPC Gateway Endpoint for S3** - Must be configured at VPC level
2. **IAM Role** - RDS instance must have IAM role with S3 write permissions
3. **S3 Bucket** - Bucket must exist with appropriate permissions
4. **S3 Bucket Policy** - Allow RDS instance to write to the bucket

#### Region-Based Configuration with Jinja Templates

All backup parameters can be configured per region using Jinja templates in GitOps. This allows you to:
- Set different backup schedules for different regions/timezones
- Enable/disable backups per region
- Configure different S3 buckets per region
- Adjust backup performance parameters based on region requirements

**Example Jinja Template Configuration:**

```yaml
# config/<region>/120-ibm-dbs-rds-database-values.yaml.j2
backup:
  enabled: {{ backup_enabled | default(true) }}
  s3_bucket_name: "{{ s3_backup_bucket }}"
  s3_prefix: "{{ cluster_name }}/db2-backups"
  
  # Common backup parameters
  compression: "{{ backup_compression | default('INCLUDE') }}"
  util_impact_priority: {{ backup_util_impact_priority | default(50) }}
  num_files: {{ backup_num_files | default(4) }}
  parallelism: {{ backup_parallelism | default(4) }}
  num_buffers: {{ backup_num_buffers | default(8) }}
  
  full:
    enabled: {{ full_backup_enabled | default(true) }}
    schedule: "{{ full_backup_schedule | default('0 2 * * 0') }}"
  
  incremental:
    enabled: {{ incremental_backup_enabled | default(true) }}
    schedule: "{{ incremental_backup_schedule | default('0 2 * * 1-6') }}"
```

**Region Variables Example:**

```yaml
# config/us-east-1/variables.yaml
backup_enabled: true
full_backup_enabled: true
incremental_backup_enabled: true
full_backup_schedule: "0 2 * * 0"  # Sunday 2 AM UTC
incremental_backup_schedule: "0 2 * * 1-6"  # Mon-Sat 2 AM UTC
s3_backup_bucket: "prod-us-east-1-db2-backups"

# config/eu-west-1/variables.yaml
backup_enabled: true
full_backup_enabled: true
incremental_backup_enabled: true
full_backup_schedule: "0 3 * * 0"  # Sunday 3 AM UTC (adjusted for timezone)
incremental_backup_schedule: "0 3 * * 1-6"  # Mon-Sat 3 AM UTC
s3_backup_bucket: "prod-eu-west-1-db2-backups"
```

See `templates/JINJA_EXAMPLE.md` for comprehensive examples of region-based configuration.

## Templates

### 00-configmap.yaml
Creates a ConfigMap with Python script that performs all DB2 RDS initialization and configuration:
- Creates bufferpools and tablespaces based on MAS application type
- Applies DB2 instance registry settings using `CALL rdsadmin.update_db_param('database_name', 'key', 'value')`
- Applies DB2 database configuration using `CALL rdsadmin.update_db_param('database_name', 'key', 'value')`
- Applies DB2 instance DBM configuration using `CALL rdsadmin.update_db_param('database_name', 'key', 'value')`
- Configures DB2 audit settings using `CALL rdsadmin.update_db_param('database_name', 'AUDIT_BUF_SZ', '1000')`

### 01-dbs-rds-postsync-setup.yaml
Job that runs the initialization script:
- **Sync Wave**: 136
- Creates secret with database credentials
- Executes the Python script from ConfigMap
- Passes all configuration values as environment variables (JSON format)
- Downloads RDS SSL certificate for secure connections

### 02-backup-script-configmap.yaml
Creates a ConfigMap with Python backup script:
- **Sync Wave**: 135
- Contains comprehensive RDS DB2 backup logic
- Supports both FULL and INCREMENTAL backup types
- Connects to rdsadmin database using SSL
- Calls `rdsadmin.backup_database` stored procedure
- Monitors backup progress using `rdsadmin.get_task_status`
- Organizes backups in S3 with timestamp-based structure

### 03-backup-cronjobs.yaml
Creates CronJob resources for automated backups:
- **Sync Wave**: 137
- **Full Backup CronJob**: Runs weekly (default: Sundays at 2 AM)
  - Configurable schedule via `backup.full.schedule`
  - Can be disabled via `backup.full.enabled`
  - Executes FULL backup to S3
- **Incremental Backup CronJob**: Runs daily except Sundays (default: Mon-Sat at 2 AM)
  - Configurable schedule via `backup.incremental.schedule`
  - Can be disabled via `backup.incremental.enabled`
  - Executes INCREMENTAL backup to S3
- Both jobs use the backup script from ConfigMap
- Credentials mounted from `dbs-rds-secret-store` secret
- SSL certificate automatically downloaded for secure connections

## Usage

This chart is typically deployed via the root application at:
`root-applications/ibm-mas-instance-root/templates/120-dbs-rds-databases-app.yaml`

The root application iterates over `ibm_dbs_rds_databases` configuration and creates a separate ArgoCD Application for each database instance, passing all configuration values to this chart.

### Example Configurations

#### Manage Database
```yaml
ibm_dbs_rds_databases:
  - db2_namespace: rds-inst8
    db2_instance_name: rds-inst8-manage
    mas_application_id: manage
    host: "db2-rds-endpoint.us-east-1.rds.amazonaws.com"
    port: 50000
    dbname: "MAXDB80"
    rds_admin_db_name: "rdsadmin"
    user: "db2inst1"
    password: "<secret>"
    replica_db: false
    db2_instance_registry:
      DB2_WORKLOAD: "MAXIMO"
      DB2_SKIPINSERTED: "ON"
    db2_database_db_config:
      AUTO_MAINT: "OFF"
      LOCKTIMEOUT: "300"
    db2_addons_audit_config:
      enableAudit: true
      applyDefaultPolicy: true
```

#### Facilities Database
```yaml
ibm_dbs_rds_databases:
  - db2_namespace: rds-inst8
    db2_instance_name: rds-inst8-facilities
    mas_application_id: facilities
    host: "db2-rds-endpoint.us-east-1.rds.amazonaws.com"
    port: 50000
    dbname: "TRIDB80"
    rds_admin_db_name: "rdsadmin"
    user: "db2inst1"
    password: "<secret>"
    replica_db: true
    db2_instance_registry:
      DB2_COMPATIBILITY_VECTOR: "ORA"
      DB2_PARALLEL_IO: "*"
    db2_database_db_config:
      CATALOGCACHE_SZ: "2048"
      LOCKTIMEOUT: "30"
    db2_addons_audit_config:
      enableAudit: true
      applyDefaultPolicy: true
```

#### IoT Database
```yaml
ibm_dbs_rds_databases:
  - db2_namespace: rds-inst8
    db2_instance_name: rds-inst8-iot
    mas_application_id: iot
    host: "db2-rds-endpoint.us-east-1.rds.amazonaws.com"
    port: 50000
    dbname: "IOTDB80"
    rds_admin_db_name: "rdsadmin"
    user: "db2inst1"
    password: "<secret>"
    replica_db: false
    db2_addons_audit_config:
      enableAudit: true
      applyDefaultPolicy: true
```

## Sync Waves

The chart uses ArgoCD sync waves to ensure proper ordering:

1. **Wave 135**: ConfigMaps with initialization and backup scripts
   - `00-configmap.yaml`: DB2 initialization script
   - `02-backup-script-configmap.yaml`: Backup script
2. **Wave 136**: Secret and job that executes all DB2 setup:
   - Creates bufferpools and tablespaces
   - Applies DB2 instance registry settings
   - Applies DB2 database configuration
   - Applies DB2 instance DBM configuration
   - Configures audit settings (if enabled)
3. **Wave 137**: Backup CronJobs
   - Full backup CronJob (weekly)
   - Incremental backup CronJob (daily)

## Notes

- All jobs are idempotent and can be safely re-run
- Jobs use the `mas.ibm.com/job-cleanup-group` label for automatic cleanup
- SSL/TLS is enforced for all database connections
- The RDS global certificate bundle is automatically downloaded
- Backup CronJobs can be individually enabled/disabled via configuration
- Backup schedules are fully customizable using standard cron syntax
- Backups are stored in S3 with organized folder structure by database, type, and timestamp
- Backup monitoring is built-in with automatic status checking