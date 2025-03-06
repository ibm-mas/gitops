MAS SaaS Job Cleaner
===============================================================================

Deploys the `mas-saas-job-cleaner-cron` CronJob, responsible for cleaning up orphaned Job resources in the cluster. It works by grouping Jobs in the cluster according to the `mas.ibm.com/job-cleanup-group` label, then deleting all Jobs from each group except for the one with the latest `creationTimestamp`.

For safety, the CronJob is assigned a ServiceAccount that can only list and delete Job resources (so it can never delete any other type of resource). Furthermore, the logic ensures that only Job resources with the `mas.ibm.com/job-cleanup-group` label can be deleted.

The `mas-devops-saas-job-cleaner` command executed by this CronJob is defined in [python-devops](https://github.com/ibm-mas/python-devops/blob/stable/bin/mas-devops-saas-job-cleaner).


> In MaS SaaS, Job resources are routinely orphaned (i.e. marked for deletion by ArgoCD) since, when an update is required to an immutable Job field (e.g. its image tag), a new version of the Job resource must be created with a different name. When [auto_delete: false](https://ibm-mas.github.io/gitops/main/accountrootmanifest/#auto_delete) is set, ArgoCD will (by design) not perform this cleanup for us. Over time, Job resources will accumulate and put pressure on the K8S API server.