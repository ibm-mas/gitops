IBM CIS Compliance
===============================================================================
Installs IBM Compliance Operator into the `openshift-compliance` namespace and add disable rules in tailoredprofile for limitation on ROSA

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `compliance-operator` | `openshift-compliance` | Always | `cluster_admin_role` |
| `Subscription` | `compliance-operator-sub` | `openshift-compliance` | Always | `cluster_admin_role` |
| `ScanSettingBinding` | `mas-cis-compliance` | `openshift-compliance` | Always | `cluster_admin_role` |
| `TailoredProfile` | `mas-ocp4-cis-node-rosa-tailoredprofile` | `openshift-compliance` | Always | `cluster_admin_role` |
| `TailoredProfile` | `mas-ocp4-cis-rosa-tailoredprofile` | `openshift-compliance` | Always | `cluster_admin_role` |
| `Job` | `postdelete-delete-profilebundles-job` | `openshift-compliance` | PostDelete hook only | `cluster_admin_role` |

**Note:** The TailoredProfiles disable specific rules that cannot be modified in ROSA environments (e.g., Kubelet config modifications).