IBM MAS Post Sync Jobs
===============================================================================
Instantiated by the /gitops/root-applications/ibm-mas-instance-root/templates/600-ibm-post-sync-jobs.yaml root application.

<!--docs-include-start-->
## Overview

This chart runs post-sync Jobs after the MAS instance installation completes, performing tasks such as updating AWS Secrets Manager with instance credentials and triggering downstream configuration hooks.



Defines Jobs to perform various tasks that need to happen after MAS applications are installed and ready.

## Configuration

### Values

```yaml
ibm_post_sync_jobs:
  run_sync_hooks: true
```

## Examples

### Default post-sync job configuration

```yaml
merge-key: "my-account/my-cluster/inst1"
ibm_post_sync_jobs:
  run_sync_hooks: true
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | Initial user/bootstrap runtime secret | MAS core namespace | Always | `application_admin_role` |
| `NetworkPolicy` | Initial user creation network policy | MAS core namespace | Always | `application_admin_role` |
| `ServiceAccount` | Initial user creation service account | MAS core namespace | Always | `application_admin_role` |
| `Role` | Initial user creation roles | MAS core namespace | Always | `application_admin_role` |
| `RoleBinding` | Initial user creation role bindings | MAS core namespace | Always | `application_admin_role` |
| `Job` | Initial user creation post-sync job | MAS core namespace | Always | `application_admin_role` |
