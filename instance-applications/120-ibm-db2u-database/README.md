IBM DB2U Database
===============================================================================
Create a Db2u database for a MAS app.

<!--docs-include-start-->

## Overview

This chart deploys and configures a Db2u database instance for use by a MAS application. It manages the full lifecycle of the database including TLS certificates, storage, backup, audit log extraction, and HADR services.

Contains a presync hook (`00-presync-await-crd_Job.yaml`) that ensures we wait for the `db2uclusters` CRD to be installed before attempting to sync.

Contains a job that runs last (`05-postsync-setup-db2_Job.yaml`). This registers the `${ACCOUNT_ID}/${CLUSTER_ID}/${MAS_INSTANCE_ID}/db2/${DB2_INSTANCE_NAME}/config` secret in the **Secrets Vault** used to share some information that is generated at runtime with other ArgoCD Applications. This job also performs some special configuration steps that are required if the Db2u database is intended for use by the Manage MAS Application.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition                                                   | Installed By |
|--------------|---------------|-----------|-------------------------------------------------------------|--------------|
| `StorageClass` | Db2 storage class definitions | DB2 application namespace / cluster | When storage classes are managed by this chart              | `application_admin_role` |
| `ServiceAccount` | Pre/post-sync DB2 job service accounts | DB2 application namespace | Always                                                      | `application_admin_role` |
| `Role` | Pre/post-sync DB2 job roles | DB2 application namespace and related namespaces | Always                                                      | `application_admin_role` |
| `RoleBinding` | Pre/post-sync DB2 job role bindings | DB2 application namespace and related namespaces | Always                                                      | `application_admin_role` |
| `Issuer` | DB2 TLS issuers | DB2 application namespace | Always                                                      | `application_admin_role` |
| `Certificate` | DB2 TLS certificates | DB2 application namespace | Always                                                      | `application_admin_role` |
| `Db2uInstance` | Db2u instance CR | DB2 application namespace | Always                                                      | `application_admin_role` |
| `CronJob` | Db2 backup cron job | DB2 application namespace | When backups are enabled (`db2_backup_bucket_name` set)     | `application_admin_role` |
| `CronJob` | Db2 audit extract cron job | DB2 application namespace | When backup bucket is enabled (`db2_audit_bucket_name` set) | `application_admin_role` |
| `ConfigMap` | Db2 script/config maps | DB2 application namespace | Always                                                      | `application_admin_role` |
| `Route` | Db2 TLS route | DB2 application namespace | When route exposure is enabled                              | `application_admin_role` |
| `Service` | Db2 services, including HADR services | DB2 application namespace | Always                                                      | `application_admin_role` |
| `Service` | Private NLB service | DB2 application namespace | When `private_nlb.enabled` is true                          | `application_admin_role` |
| `Secret` | Post-sync DB2 generated secret | DB2 application namespace | Always                                                      | `application_admin_role` |
| `NetworkPolicy` | HADR network policy | DB2 application namespace | When HADR is enabled                                        | `application_admin_role` |
| `Job` | Pre/post-sync DB2 setup jobs | DB2 application namespace | Always                                                      | `application_admin_role` |

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

# Audit Log Configuration (IRSA - Recommended)
db2_audit_irsa_role_arn: string (optional, IAM Role ARN for IRSA)

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

### Validation

If `private_nlb.enabled: true` and either `subnet_ids` or `allowed_cidrs` is
empty, Helm will fail immediately with a clear error message before rendering
any resources. This prevents a broken or unrestricted NLB from being deployed.

## Prerequisites

- The `db2uclusters` CRD must be available on the cluster (ensured by the presync hook).
- An S3-compatible backup bucket must be provisioned when backup or audit log upload is enabled.
- Secrets for S3 credentials, cluster domain, and Secrets Manager access must be pre-populated in the Secrets Vault before sync.

## Examples

### Minimal deployment

```yaml
db2_namespace: db2u-manage
db2_instance_name: db2u-manage
db2_dbname: BLUDB
db2_version: "11.5.9.0"
db2_tls_version: "1.2"
db2_table_org: ROW
mas_application_id: manage
cluster_domain: "<path:secrets/path:cluster_domain>"
```

### With backup and audit log upload enabled

```yaml
db2_namespace: db2u-manage
db2_instance_name: db2u-manage
db2_dbname: BLUDB
db2_backup_bucket_name: "<path:secrets/path:bucket_name>"
db2_backup_bucket_endpoint: "<path:secrets/path:bucket_endpoint>"
db2_backup_bucket_access_key: "<path:secrets/path:access_key>"
db2_backup_bucket_secret_key: "<path:secrets/path:secret_key>"
### With IRSA (IAM Role for Service Account) - Recommended

Using IRSA eliminates the need for IAM User credentials and improves security posture for AWS AccessHub (ITSS) compliance:

```yaml
db2_namespace: db2u-manage
db2_instance_name: db2u-manage
db2_dbname: BLUDB
db2_backup_bucket_name: "<path:secrets/path:bucket_name>"
db2_backup_bucket_endpoint: "<path:secrets/path:bucket_endpoint>"
auto_backup: true
mas_application_id: manage
cluster_domain: "<path:secrets/path:cluster_domain>"

# IRSA Configuration - replaces access_key/secret_key
db2_audit_irsa_role_arn: "arn:aws:iam::123456789012:role/db2-audit-s3-access"
```

#### IRSA Architecture

**Important:** The AWS CLI runs **inside the DB2 pod**, not the CronJob pod. The CronJob only executes `oc rsh` to run commands in the DB2 pod.

```
CronJob SA (account-{namespace}-{instance})
    │
    │ Kubernetes RBAC ONLY
    │ - pods: get, list
    │ - pods/exec: create
    │ (NO secret access needed)
    ▼
DB2U Pod (c-{instance}-db2u-0)
    │
    │ DB2U ServiceAccount (db2u-{instance_name})
    │ eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/NAME
    │
    │ OIDC Web Identity Token
    │ /var/run/secrets/eks.amazonaws.com/serviceaccount/token
    ▼
AWS STS (AssumeRoleWithWebIdentity)
    │
    │ Validates OIDC token
    │ Returns temporary credentials
    ▼
IAM Role: db2-audit-log-writer
    │
    │ S3 Policy (Minimal):
    │ - s3:PutObject (REQUIRED - upload audit logs)
    │
    │ Optional (for troubleshooting):
    │ - s3:GetObject (verify uploads)
    │ - s3:ListBucket (list files)
    ▼
S3 Bucket: audit-logs-bucket
    │
    │ Path: audit_logs/{app}/{YYYY-MM-DD}/
    │ Optional: Object Lock (WORM - prevents deletion/modification)
    ▼
Immutable Audit Logs
```

**Key Points:**
- **CronJob ServiceAccount (`account-{namespace}-{instance}`):**
  - Minimal Kubernetes RBAC only
  - Can exec into DB2 pod
  - NO AWS permissions
  - NO secret access

- **DB2 Pod ServiceAccount (`db2u-{instance_name}`):**
  - Has IRSA annotation with IAM Role ARN
  - Provides AWS credentials to DB2 pod
  - Used by AWS CLI inside the pod

- **IAM Role:**
  - Assumed by DB2 pod via OIDC
  - Grants S3 access
  - No long-term credentials

- **S3 Object Lock (Optional):**
  - Ensures audit logs are immutable
  - Prevents deletion/modification

The IRSA annotation is applied to the **DB2 pod's ServiceAccount** (`db2u-{instance_name}`), not the CronJob's ServiceAccount.

#### IRSA Setup Requirements

1. **Create IAM Role** with trust policy allowing the DB2 pod's ServiceAccount:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:NAMESPACE:db2u-INSTANCE_NAME"
           }
         }
       }
     ]
   }
   ```

   **Example for db2u-manage:**
   ```json
   "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539:sub": "system:serviceaccount:db2u-manage:db2u-db2u-manage"
   ```

2. **Attach S3 Policy** to the IAM Role:
   
   **Minimal policy (recommended):**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:PutObject"
         ],
         "Resource": [
           "arn:aws:s3:::BUCKET_NAME/audit_logs/*"
         ]
       }
     ]
   }
   ```
   
   **With troubleshooting permissions (optional):**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:PutObject",
           "s3:GetObject",
           "s3:ListBucket"
         ],
         "Resource": [
           "arn:aws:s3:::BUCKET_NAME",
           "arn:aws:s3:::BUCKET_NAME/*"
         ]
       }
     ]
   }
   ```
   
   **Note:** The audit script only uploads files (`aws s3 cp`), so `s3:PutObject` is the only required permission. Additional permissions are optional for verification and troubleshooting.

3. **Configure the chart** with `db2_audit_irsa_role_arn` as shown above.

**Benefits of IRSA:**
- No credential rotation required
- Improved ITSS (AWS AccessHub) security score
- Automatic credential management by AWS
- Follows AWS security best practices

auto_backup: true
mas_application_id: manage
cluster_domain: "<path:secrets/path:cluster_domain>"
```

## Troubleshooting

- **Presync job stuck** — verify the `db2uclusters` CRD is installed by the DB2U operator before the ArgoCD sync wave reaches this chart.
- **Postsync job failing** — check the job logs in the DB2 namespace; common causes are missing S3 credentials or an unreachable backup bucket.
- **Audit CronJob not running** — confirm `db2_backup_bucket_name` is set and the instance name does not contain `sdb` (audit cron is disabled for SDB instances).
- **AWS CLI missing** — `db2AuditExtract.sh` will install the AWS CLI automatically on first run via `curl`/`unzip` into `/mnt/backup/`.

## Related Documentation

- [Instance Base Values Reference](../../docs/reference/instance-base-values.md)
- [IBM Db2u Operator Documentation](https://www.ibm.com/docs/en/db2/11.5)
