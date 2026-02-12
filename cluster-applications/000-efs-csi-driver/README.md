EFS CSI Driver
===============================================================================

Installs the AWS EFS CSI Driver operator to enable EFS-backed persistent volumes in OpenShift.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | `aws-efs-cloud-credentials` | `openshift-cluster-csi-drivers` | Always | `cluster_admin_role` |
| `OperatorGroup` | `openshift-cluster-csi-drivers-operator-group` | `openshift-cluster-csi-drivers` | Always | `cluster_admin_role` |
| `Subscription` | `aws-efs-csi-driver-operator` | `openshift-cluster-csi-drivers` | Always | `cluster_admin_role` |
| `ClusterCSIDriver` | `efs.csi.aws.com` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
