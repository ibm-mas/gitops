Cluster Promotion
===============================================================================
Takes cluster level changes and promotes them to the next level

<!--docs-include-start-->


## Configuration

### Values

```yaml
promotion:
  # GitHub Personal Access Token (required)
  # Token with permissions to create pull requests in target repository
  github_pat: ""

  # Target GitHub host (required)
  # GitHub server hostname
  # Example: github.com or github.ibm.com
  target_github_host: ""

  # Target GitHub repository (required)
  # Repository name where changes will be promoted
  target_github_repo: ""

  # Target GitHub organization (required)
  # Organization or user owning the target repository
  target_github_org: ""

  # Target GitHub path (required)
  # Path within the repository where changes will be committed
  # Example: config/clusters
  target_github_path: ""

  # Target Git branch (required)
  # Branch where changes will be committed
  # Example: main, develop
  target_git_branch: ""

  # Create target pull request (required)
  # Whether to create a PR or commit directly
  # Options: "true" or "false"
  create_target_pr: "true"

  # Cluster values to promote (required)
  # List of cluster configuration values to include in promotion
  # Example: ["cluster-id", "region", "environment"]
  cluster_values: []

  # Target PR title (optional)
  # Title for the pull request when create_target_pr is true
  # Default: "Cluster promotion for <cluster_id>"
  target_pr_title: ""
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

**Basic cluster promotion with PR:**
```yaml
promotion:
  github_pat: "ghp_xxxxxxxxxxxx"
  target_github_host: "github.com"
  target_github_repo: "mas-config"
  target_github_org: "my-company"
  target_github_path: "config/production"
  target_git_branch: "main"
  create_target_pr: "true"
  cluster_values:
    - "cluster-id"
    - "region"
    - "environment"
  target_pr_title: "Promote cluster configuration to production"
```

**Direct commit without PR:**
```yaml
promotion:
  github_pat: "ghp_xxxxxxxxxxxx"
  target_github_host: "github.com"
  target_github_repo: "mas-config"
  target_github_org: "my-company"
  target_github_path: "config/staging"
  target_git_branch: "develop"
  create_target_pr: "false"
  cluster_values:
    - "cluster-id"
    - "region"
```

**Enterprise GitHub with custom values:**
```yaml
promotion:
  github_pat: "ghp_xxxxxxxxxxxx"
  target_github_host: "github.ibm.com"
  target_github_repo: "mas-gitops-config"
  target_github_org: "ibm-mas"
  target_github_path: "clusters/production"
  target_git_branch: "main"
  create_target_pr: "true"
  cluster_values:
    - "cluster-id"
    - "region"
    - "environment"
  - "account-id"
  - "cluster-domain"
target_pr_title: "Automated cluster promotion - Production"
```

### How It Works

1. **Cluster Verify Job** - Validates the current cluster state and configuration
2. **Cluster Promoter Job** - Extracts specified cluster values and commits them to the target repository
3. **Pull Request** - Optionally creates a PR for review before merging changes

This enables automated promotion of cluster configurations from one environment to another (e.g., dev → staging → production).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | `cluster-promoter-<cluster_id>-cm` | `mas-syncres` | Always | `cluster_admin_role` |
| `ServiceAccount` | `cluster-verify-sa` | `mas-syncres` | Always | `cluster_admin_role` |
| `ClusterRole` | `cluster-verify-cr` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ClusterRoleBinding` | `cluster-verify-crb` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `Job` | `cluster-verify-*` | `mas-syncres` | Always | `cluster_admin_role` |
| `Job` | `cluster-promoter-*` | `mas-syncres` | Always | `cluster_admin_role` |

**Note:** The cluster-verify Job validates the cluster state before the cluster-promoter Job promotes configuration changes to the next environment level.
