EFS CSI Driver
===============================================================================


<!--docs-include-start-->

Installs the AWS EFS CSI Driver operator to enable EFS-backed persistent volumes in OpenShift.

## Configuration

### Values

```yaml
# EFS CSI Driver operator configuration
efs_csi_driver:
  # Operator catalog source
  # Default: redhat-operators
  catalog_source: redhat-operators
  
  # Catalog source namespace
  # Default: openshift-marketplace
  catalog_source_namespace: openshift-marketplace
  
  # Subscription channel
  # Default: stable
  channel: stable
  
  # Subscription source namespace
  # Default: openshift-cluster-csi-drivers
  subscription_source_namespace: openshift-cluster-csi-drivers
  
  # IAM role ARN for EFS CSI driver (required for AWS)
  # Example: arn:aws:iam::123456789012:role/efs-csi-driver-role
  role_arn: ""
  
  # Storage class name (optional)
  # If not specified, uses default storage class naming
  storage_class_name: ""

# Custom storage class definitions (optional)
# Define multiple storage classes with different EFS configurations
storage_class_definitions: {}
  # Example:
  # efs-general:
  #   provisioner: efs.csi.aws.com
  #   parameters:
  #     provisioningMode: efs-ap
  #     fileSystemId: fs-12345678
  #     directoryPerms: "700"
  #   reclaimPolicy: Delete
  #   volumeBindingMode: Immediate
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

**Basic configuration with IAM role:**
```yaml
efs_csi_driver:
  role_arn: "arn:aws:iam::123456789012:role/efs-csi-driver-role"
```

**With custom storage class name:**
```yaml
efs_csi_driver:
  role_arn: "arn:aws:iam::123456789012:role/efs-csi-driver-role"
  storage_class_name: efs-rwx
```

**With multiple custom storage classes:**
```yaml
efs_csi_driver:
  role_arn: "arn:aws:iam::123456789012:role/efs-csi-driver-role"

storage_class_definitions:
  efs-general:
    provisioner: efs.csi.aws.com
    parameters:
      provisioningMode: efs-ap
      fileSystemId: fs-abcd1234
      directoryPerms: "755"
    reclaimPolicy: Delete
    volumeBindingMode: Immediate
  
  efs-retain:
    provisioner: efs.csi.aws.com
    parameters:
      provisioningMode: efs-ap
      fileSystemId: fs-abcd1234
      directoryPerms: "700"
    reclaimPolicy: Retain
    volumeBindingMode: Immediate
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | `aws-efs-cloud-credentials` | `openshift-cluster-csi-drivers` | Always | `cluster_admin_role` |
| `OperatorGroup` | `openshift-cluster-csi-drivers-operator-group` | `openshift-cluster-csi-drivers` | Always | `cluster_admin_role` |
| `Subscription` | `aws-efs-csi-driver-operator` | `openshift-cluster-csi-drivers` | Always | `cluster_admin_role` |
| `ClusterCSIDriver` | `efs.csi.aws.com` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `StorageClass` | EFS storage classes | N/A (cluster-scoped) | Always | `cluster_admin_role` |
