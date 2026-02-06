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

1. **Wave 135**: ConfigMap with comprehensive initialization and configuration script
2. **Wave 136**: Secret and job that executes all DB2 setup:
   - Creates bufferpools and tablespaces
   - Applies DB2 instance registry settings
   - Applies DB2 database configuration
   - Applies DB2 instance DBM configuration
   - Configures audit settings (if enabled)

## Notes

- All jobs are idempotent and can be safely re-run
- Jobs use the `mas.ibm.com/job-cleanup-group` label for automatic cleanup
- SSL/TLS is enforced for all database connections
- The RDS global certificate bundle is automatically downloaded