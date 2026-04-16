IBM DB2U Database
===============================================================================
Create a Db2u database for a MAS app.

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
| `Secret` | Post-sync DB2 generated secret | DB2 application namespace | Always | `application_admin_role` |
| `NetworkPolicy` | HADR network policy | DB2 application namespace | When HADR is enabled | `application_admin_role` |
| `Job` | Pre/post-sync DB2 setup jobs | DB2 application namespace | Always | `application_admin_role` |
