IBM MAS Sync Jobs
===============================================================================
Instantiated by the /gitops/root-applications/ibm-mas-instance-root/templates/91-ibm-sync-jobs.yaml root application.

Defines Jobs to perform various tasks that need to happen before ibm-sls and the suite are installed, and after they are removed.

Supporting resources are defined in the 90-ibm-sync-resources chart which is managed by an application with a lower syncwave (90).
This is to ensure that these resources perist long enough for any PostDelete hooks in this chart to complete.
