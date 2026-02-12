IBM MAS Provisioner (For Internal Use Only)
===============================================================================
Installs the MAS Provisioner service which sends a notification when an order comes through AWS market place. The MAS provisioner service broker is intended for internal use only.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | `ibm-entitlement` | `mas-provisioner` | Always | `cluster_admin_role` |
| `ServiceAccount` | `mas-provisioner` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Certificate` | `mas-provisioner-cert` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Secret` | `mas-provisioner-tls` | `mas-provisioner` | Always | `cluster_admin_role` |
| `PersistentVolumeClaim` | `mas-provisioner-pvc` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Service` | `mas-provisioner` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Deployment` | `mas-provisioner` | `mas-provisioner` | Always | `cluster_admin_role` |
| `Route` | `mas-provisioner` | `mas-provisioner` | Always | `cluster_admin_role` |

**Note:** This service is for internal IBM use only and handles AWS Marketplace order notifications.
