IBM MAS Sync Resources
===============================================================================
Instantiated by the /gitops/root-applications/ibm-mas-instance-root/templates/90-ibm-sync-resources.yaml root application.

Various resources required to run Jobs contained in the 91-ibm-sync-jobs chart.
This application has a lower syncwave (90) than that of the 91-ibm-sync-jobs application responsible for running the jobs.
This is to ensure that the resources to persist long enough for the PostDelete hooks in that 91-ibm-sync-jobs to complete,
while still being cleaned up successfully when MAS instance is deprovisioned.

