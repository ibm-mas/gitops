Nvidia GPU Operator
===============================================================================
Installs the Nvidia GPU Operator

<!--docs-include-start-->


## Configuration

### Values

```yaml
nvidia_gpu_operator:
  # NFD (Node Feature Discovery) configuration
  # NFD is a prerequisite for GPU operator
  nfd_namespace: "openshift-nfd"
  nfd_channel: "stable"
  nfd_install_plan: Automatic
  nfd_image: ""  # Optional: custom NFD image

  # GPU Operator configuration
  # Namespace where GPU operator will be installed
  # Default: nvidia-gpu-operator
  gpu_namespace: "nvidia-gpu-operator"

  # GPU Operator subscription channel
  # Default: v24.3
  gpu_channel: "v24.3"

  # NVIDIA GPU driver version
  # Specify the driver version to install
  # Default: 575.57.08
  gpu_driver_version: 575.57.08

  # GPU driver repository path
  # Container registry path for GPU drivers
  # Default: nvcr.io/nvidia
  gpu_driver_repository_path: "nvcr.io/nvidia"

  # GPU Operator install plan approval
  # Options: "Automatic" or "Manual"
  # Default: Automatic
  gpu_install_plan: Automatic
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

**Basic GPU operator installation:**
```yaml
nvidia_gpu_operator:
  nfd_namespace: "openshift-nfd"
  nfd_channel: "stable"
  nfd_install_plan: Automatic
  gpu_namespace: "nvidia-gpu-operator"
  gpu_channel: "v24.3"
  gpu_driver_version: 575.57.08
  gpu_driver_repository_path: "nvcr.io/nvidia"
  gpu_install_plan: Automatic
```

**With specific driver version:**
```yaml
nvidia_gpu_operator:
  nfd_namespace: "openshift-nfd"
  nfd_channel: "stable"
  nfd_install_plan: Automatic
  gpu_namespace: "nvidia-gpu-operator"
  gpu_channel: "v24.3"
  gpu_driver_version: 550.90.07
  gpu_driver_repository_path: "nvcr.io/nvidia"
  gpu_install_plan: Automatic
```

**With custom driver repository:**
```yaml
nvidia_gpu_operator:
  nfd_namespace: "openshift-nfd"
  nfd_channel: "stable"
  nfd_install_plan: Automatic
  gpu_namespace: "nvidia-gpu-operator"
  gpu_channel: "v24.3"
  gpu_driver_version: 575.57.08
  gpu_driver_repository_path: "my-registry.example.com/nvidia"
  gpu_install_plan: Automatic
```

### Prerequisites

- OpenShift cluster with GPU-enabled nodes
- Sufficient cluster resources for GPU workloads
- Node Feature Discovery (NFD) operator (automatically installed by this chart)

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `nvidia-gpu-operator-group` | `nvidia-gpu-operator` | Always | `cluster_admin_role` |
| `Subscription` | `gpu-operator-certified` | `nvidia-gpu-operator` | Always | `cluster_admin_role` |
| `ClusterPolicy` | `gpu-cluster-policy` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `SecurityContextConstraints` | `ibm-mas-customscc` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
