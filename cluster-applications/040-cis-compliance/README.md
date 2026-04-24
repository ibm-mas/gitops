IBM CIS Compliance
===============================================================================
Installs IBM Compliance Operator into the `openshift-compliance` namespace and add disable rules in tailoredprofile for limitation on ROSA

<!--docs-include-start-->


## Configuration

### Values

```yaml
cis_compliance:
  # Configuration flag (internal use)
  # This flag is used by the parent application to determine readiness
  # Default: true
  config: true

  # Compliance Operator install plan approval
  # Options: "Automatic" or "Manual"
  # Default: Automatic
  cis_install_plan: Automatic
```

## Base Cluster Values

This chart inherits common cluster configuration values. The most frequently used base values are:

```yaml
account:
  id: string                    # AWS account identifier

region:
  id: string                    # AWS region identifier

cluster:
  id: string                    # Unique cluster identifier
  url: string                   # OpenShift cluster API URL
  nonshared: boolean            # Whether cluster is dedicated (true) or shared (false)

sm:                             # Secrets Manager configuration
  aws_access_key_id: string (secret reference)
  aws_secret_access_key: string (secret reference)
```

For complete documentation of all base cluster values including optional fields like `notifications`, `custom_labels`, `devops`, and `cli_image_repo`, see the [Cluster Base Values Reference](../../docs/reference/cluster-base-values.md).

### Usage Examples

**Basic configuration with automatic updates:**
```yaml
cis_compliance:
  config: true
  cis_install_plan: Automatic
```

**Manual approval for operator updates:**
```yaml
cis_compliance:
  config: true
  cis_install_plan: Manual
```

### About CIS Compliance

This chart installs the OpenShift Compliance Operator and configures it to run CIS (Center for Internet Security) benchmark scans on your cluster. The TailoredProfiles included are specifically configured for ROSA (Red Hat OpenShift Service on AWS) environments, disabling rules that cannot be modified in managed OpenShift services.

The compliance scans run automatically based on the ScanSetting configuration and results are stored as ComplianceCheckResult resources in the cluster.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `compliance-operator` | `openshift-compliance` | Always | `cluster_admin_role` |
| `Subscription` | `compliance-operator-sub` | `openshift-compliance` | Always | `cluster_admin_role` |
| `ScanSetting` | `default-auto-apply` | `openshift-compliance` | Always | `cluster_admin_role` |
| `ScanSettingBinding` | `mas-cis-compliance` | `openshift-compliance` | Always | `cluster_admin_role` |
| `TailoredProfile` | `mas-ocp4-cis-node-rosa-tailoredprofile` | `openshift-compliance` | Always | `cluster_admin_role` |
| `TailoredProfile` | `mas-ocp4-cis-rosa-tailoredprofile` | `openshift-compliance` | Always | `cluster_admin_role` |
| `ServiceAccount` | compliance cleanup service accounts | `openshift-compliance` | Cleanup resources as applicable | `cluster_admin_role` |
| `Role` | compliance cleanup roles | `openshift-compliance` | Cleanup resources as applicable | `cluster_admin_role` |
| `RoleBinding` | compliance cleanup role bindings | `openshift-compliance` | Cleanup resources as applicable | `cluster_admin_role` |

**Note:** The TailoredProfiles disable specific rules that cannot be modified in ROSA environments (e.g., Kubelet config modifications).
