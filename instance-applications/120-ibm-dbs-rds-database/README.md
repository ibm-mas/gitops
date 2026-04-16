IBM DB2U Database
===============================================================================
Create a Db2RDS database for a MAS app.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | RDS setup and backup script config maps | Application namespace | Always | `application_admin_role` |
| `Secret` | RDS post-sync generated secret | Application namespace | When post-sync setup runs | `application_admin_role` |
| `Job` | RDS post-sync setup job | Application namespace | Always | `application_admin_role` |
| `CronJob` | RDS backup cron jobs | Application namespace | When backups are enabled | `application_admin_role` |