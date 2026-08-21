IBM DB2U Database
===============================================================================
Create a Db2u database for a MAS app.

<!--docs-include-start-->


Contains a presync hook (`00-presync-await-crd_Job.yaml`) that ensures we wait for the db2uclusters CRD to be installed before attempting to sync.

Contains a job that runs last (`05-postsync-setup-db2_Job.yaml`). This registers the `${ACCOUNT_ID}/${CLUSTER_ID}/${MAS_INSTANCE_ID}/db2/${DB2_INSTANCE_NAME}/config` secret in the **Secrets Vault** used to share some information that is generated at runtime with other ArgoCD Applications. This job also performs some special configuration steps that are required if the Db2u database is intended for use by the Manage MAS Application.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `StorageClass` | Db2 storage class definitions | DB2 application namespace / cluster | When storage classes are managed by this chart | `application_admin_role` |
| `ServiceAccount` | Pre/post-sync DB2 job service accounts | DB2 application namespace | Always | `application_admin_role` |
| `Role` | Pre/post-sync DB2 job roles | DB2 application namespace and related namespaces | Always | `application_admin_role` |
| `RoleBinding` | Pre/post-sync DB2 job role bindings | DB2 application namespace and related namespaces | Always | `application_admin_role` |
| `Issuer` | DB2 TLS issuers | DB2 application namespace | Always | `application_admin_role` |
| `Certificate` | DB2 TLS certificates | DB2 application namespace | Always | `application_admin_role` |
| `Db2uInstance` | Db2u instance CR | DB2 application namespace | Always | `application_admin_role` |
| `CronJob` | Db2 backup cron job | DB2 application namespace | When backups are enabled | `application_admin_role` |
| `ConfigMap` | Db2 script/config maps | DB2 application namespace | Always | `application_admin_role` |
| `Route` | Db2 TLS route | DB2 application namespace | When route exposure is enabled | `application_admin_role` |
| `Service` | Db2 services, including HADR services | DB2 application namespace | Always | `application_admin_role` |
| `Service` | Private NLB service | DB2 application namespace | When `private_nlb.enabled` is true | `application_admin_role` |
| `Secret` | Post-sync DB2 generated secret | DB2 application namespace | Always | `application_admin_role` |
| `NetworkPolicy` | HADR network policy | DB2 application namespace | When HADR is enabled | `application_admin_role` |
| `Job` | Pre/post-sync DB2 setup jobs | DB2 application namespace | Always | `application_admin_role` |
| `Job` | DB2 audit policy setup job | DB2 application namespace | When `mas_application_id` is `manage`, `facilities`, `monitor`, or `iot` | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
db2_namespace: string
db2_instance_name: string
db2_dbname: string
db2_version: string
db2_tls_version: string
db2_table_org: string
db2_node_label: string
db2_dedicated_node: string
replica_db: string

# Instance Registry Configuration
db2_instance_registry:
  key: value

# Database Configuration
db2_database_db_config:
  key: value

# Audit Configuration (optional)
db2_addons_audit_config:
  key: value

# DBM Configuration (optional)
db2_instance_dbm_config:
  key: value

# Cluster Configuration
db2_mln_count: string
db2_num_pods: string

# Storage Configuration
db2_meta_storage_class: string
db2_meta_storage_size: string
db2_meta_storage_accessmode: string
db2_data_storage_class: string
db2_data_storage_size: string
db2_data_storage_accessmode: string
db2_backup_storage_class: string
db2_backup_storage_size: string
db2_backup_storage_accessmode: string
db2_logs_storage_class: string
db2_logs_storage_size: string
db2_logs_storage_accessmode: string
db2_audit_logs_storage_class: string
db2_audit_logs_storage_size: string
db2_audit_logs_storage_accessmode: string

# Optional Storage
db2_temp_storage_class: string (optional)
db2_temp_storage_size: string (optional)
db2_temp_storage_accessmode: string (optional)
db2_archivelogs_storage_class: string (optional)
db2_archivelogs_storage_size: string (optional)
db2_archivelogs_storage_accessmode: string (optional)

# Resource Limits
db2_cpu_requests: string
db2_cpu_limits: string
db2_memory_requests: string
db2_memory_limits: string

# Affinity and Tolerations
db2_affinity_key: string
db2_affinity_value: string
db2_tolerate_key: string
db2_tolerate_value: string
db2_tolerate_effect: string

cluster_domain: string (secret reference)

# MAS Configuration
mas_application_id: string
mas_annotations: (optional)
  key: value

jdbc_route: string
jdbc_connection_url_additional_params: string (optional)
db2_timezone: string

# Storage Class Definitions (optional)
storage_class_definitions:
  key: value

# Backup Configuration
auto_backup: boolean
db2_backup_bucket_name: string (secret reference, when backup enabled)
db2_backup_bucket_endpoint: string (secret reference, when backup enabled)
db2_backup_bucket_access_key: string (secret reference, when backup enabled)
db2_backup_bucket_secret_key: string (secret reference, when backup enabled)
db2_backup_notify_slack_url: string (optional, when backup enabled)
db2_backup_icd_auth_key: string (secret reference, optional, when backup enabled)

allow_list: string (optional)

# Private NLB for customer TGW connectivity (optional)
private_nlb:
  enabled: boolean         # default: false
  subnet_ids: list(string) # required when enabled: true
  allowed_cidrs: list(string) # required when enabled: true
  port: number             # default: 50001
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

For complete documentation of all base instance values including optional fields like `custom_labels`, `argocluster_instance`, `application_admin_service_account`, `mas_wipe_mongo_data`, `allow_list`, `additional_vpn`, `application_configuration`, `use_postdelete_hooks`, `additional_resources`, `extensions`, `enhanced_dr`, and `cli_image_repo`, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md)

## Private NLB for Customer TGW Connectivity

When `private_nlb.enabled: true`, this chart creates a Kubernetes `Service` of
`type: LoadBalancer` that causes ROSA to provision an internal AWS NLB in the
specified subnets. This is the recommended approach for exposing Db2 to a customer
network via the TGW and hub-firewall path (A.4 Option 2).

ROSA automatically manages the required EC2 worker node security group rules.
No manual security group changes are needed.

| Value | Description | Required when enabled |
|---|---|---|
| `private_nlb.enabled` | Toggle NLB creation on/off | — |
| `private_nlb.subnet_ids` | Private-connectivity-edge subnet IDs, one per AZ | Yes |
| `private_nlb.allowed_cidrs` | Customer CIDRs for `loadBalancerSourceRanges` | Yes |
| `private_nlb.port` | NLB listener port, defaults to 50001 | No |

### Example — enabling for a customer-connected instance

```yaml
private_nlb:
  enabled: true
  subnet_ids:
    - subnet-0e40955c9b8865e7a   # us-gov-east-1a
    - subnet-0e53a1f9071b8d9ba   # us-gov-east-1b
    - subnet-04eba2a3f36ec0e7c   # us-gov-east-1c
  allowed_cidrs:
    - 10.200.20.0/24             # customer network CIDR
  port: 50001
```

Each Db2 instance (facilities, manage) gets its own NLB because the ArgoCD
application is deployed separately per instance with its own `db2_instance_name`.
Both can use port 50001 without conflict since they are separate AWS NLB resources.

The NLB is created independently for each instance (e.g. facilities, manage) using the instance-specific selector.

## DB2 Audit Policy

### When It Is Applied

The audit policy Job ([`08-postsync-db2-audit-policy_Job.yaml`](templates/08-postsync-db2-audit-policy_Job.yaml)) runs at sync-wave `130` (after the main DB2 setup job at wave `129`) and is **only created** when all of the following conditions are met:

1. `application_admin_role: true`
2. `mas_application_id` is one of: `manage`, `facilities`, `monitor`, `iot`
3. `should_execute: true`
4. `db2_instance_name` does not contain `sdb` (shared instances are excluded)

For any other `mas_application_id` (e.g. `health`, `visualinspection`, `predict`), no Job resource is rendered.

### What Gets Audited per Application

The job creates a single `USER_AUDIT` policy (idempotent — skipped if already exists) and assigns it to roles and/or users depending on the application:

| Application | Audit Policy | Roles Audited | User Audited |
|---|---|---|---|
| `manage` | `USER_AUDIT` | `MAXIMO_READ`, `MAXIMO_WRITE` (only if roles exist) | `db2inst1` |
| `facilities` | `USER_AUDIT` | `TRIRIGA_READ`, `TRIRIGA_WRITE` (only if roles exist) | `db2inst1` |
| `monitor` | `USER_AUDIT` | None | `db2inst1` |
| `iot` | `USER_AUDIT` | None | `db2inst1` |

### Audit Policy Definition

```sql
CREATE AUDIT POLICY USER_AUDIT
  CATEGORIES VALIDATE STATUS BOTH,
             EXECUTE WITHOUT DATA STATUS BOTH
  ERROR TYPE NORMAL
```

### Execution Steps

1. **Connect** to the database (`db2 connect to <DB2_DBNAME>`)
2. **Create** `USER_AUDIT` policy if it does not already exist
3. **Assign policy to roles** — per-app role audit (skipped if roles do not yet exist)
4. **Assign policy to user** — `AUDIT USER db2inst1 USING POLICY USER_AUDIT` (all 4 apps)
5. **Disconnect** (`db2 connect reset`)

### Validation

If `private_nlb.enabled: true` and either `subnet_ids` or `allowed_cidrs` is
empty, Helm will fail immediately with a clear error message before rendering
any resources. This prevents a broken or unrestricted NLB from being deployed..
