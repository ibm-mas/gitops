IBM MAS Sync Jobs
===============================================================================
Instantiated by the /gitops/root-applications/ibm-mas-instance-root/templates/91-ibm-sync-jobs.yaml root application.

Defines Jobs to perform various tasks that need to happen before ibm-sls and the suite are installed, and after they are removed. It also performs various tasks for CP4D when it is set to be installed or upgraded.

Supporting resources are defined in the 90-ibm-sync-resources chart which is managed by an application with a lower syncwave (90).
This is to ensure that these resources perist long enough for any PostDelete hooks in this chart to complete.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | `placeholder` | Instance-specific namespace | Always | `application_admin_role` |
| `Job` | AWS DocDB add/remove user jobs | Instance-specific namespaces | When DocDB integration is configured | `application_admin_role` |
| `Job` | IBM MAS suite cert sync job | Instance-specific namespace | When suite certificate sync is enabled | `application_admin_role` |
| `Job` | IBM MAS suite DNS sync job | Instance-specific namespace | When suite DNS sync is enabled | `application_admin_role` |
