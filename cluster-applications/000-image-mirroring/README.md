MAS Image Mirroring
===============================================================================


<!--docs-include-start-->

Establishes resources necessary to support image mirroring via an ImageDigestMirrorSet:

- `ecr-token-rotator` CronJob that rotates the ECR login token and injects it into the global pull-secret.
- `mas-ecr` `ImageDigestMirrorSet` that redirects all image pulls from icr.io and cp.icr.io to ECR

## Configuration

### Values

```yaml
image_mirroring:
  # AWS ECR host (required for ECR mirroring)
  # The ECR registry hostname where images are mirrored
  # Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com
  ecr_host: ""

  # Repository path prefix (optional)
  # Prefix to prepend to repository paths in the mirror registry
  # Example: "mas-images" or "250731"
  repo_path_prefix: ""

  # AWS Access Key ID (required for ECR authentication)
  # IAM user credentials with ECR read permissions
  # Required IAM policy actions:
  #   - ecr:GetAuthorizationToken
  #   - ecr:BatchGetImage
  #   - ecr:GetDownloadUrlForLayer
  aws_access_key_id: ""

  # AWS Secret Access Key (required for ECR authentication)
  # Corresponding secret for the AWS access key
  aws_secret_access_key: ""

  # Additional image digest sources (optional)
  # List of additional registries to include in ImageDigestMirrorSet
  # Example: ["somehost.com/repo", "another-registry.com/images"]
  additional_image_digest_sources: []

  # Additional image tag sources (optional)
  # List of registries to include in ImageTagMirrorSet for development/testing
  # Creates a separate ImageTagMirrorSet resource when specified
  # Example: ["dev-registry.com/repo"]
  additional_image_tag_sources: []
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

**Basic ECR mirroring configuration:**
```yaml
image_mirroring:
  ecr_host: "123456789012.dkr.ecr.us-east-1.amazonaws.com"
  repo_path_prefix: "mas-images"
  aws_access_key_id: "AKIAIOSFODNN7EXAMPLE"
  aws_secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

**With additional digest sources:**
```yaml
ecr_host: "123456789012.dkr.ecr.us-east-1.amazonaws.com"
repo_path_prefix: "250731"
aws_access_key_id: "AKIAIOSFODNN7EXAMPLE"
aws_secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
additional_image_digest_sources:
  - "backup-registry.example.com/mas"
  - "secondary-ecr.dkr.ecr.us-west-2.amazonaws.com"
```

**Development environment with tag-based mirroring:**
```yaml
ecr_host: "123456789012.dkr.ecr.us-east-1.amazonaws.com"
repo_path_prefix: "dev"
aws_access_key_id: "AKIAIOSFODNN7EXAMPLE"
aws_secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
additional_image_tag_sources:
  - "dev-registry.example.com/mas-dev"
```

### Required IAM Policy

The AWS credentials must have the following IAM policy attached:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "*"
    }
  ]
}
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | `aws` | `default` | Always | `cluster_admin_role` |
| `ImageDigestMirrorSet` | `mas-ecr` | N/A (cluster-scoped) | Always | `cluster_admin_role` |
| `ImageTagMirrorSet` | `mas-ecr-dev` | N/A (cluster-scoped) | When `additional_image_tag_sources` is set | `cluster_admin_role` |
| `Role` | `ecr-token-updater-role` | `default` | When `ecr_host` is set | `cluster_admin_role` |
| `ServiceAccount` | `ecr-token-updater-sa` | `default` | When `ecr_host` is set | `cluster_admin_role` |
| `RoleBinding` | `ecr-token-updater-rolebinding` | `default` | When `ecr_host` is set | `cluster_admin_role` |
| `CronJob` | `ecr-token-updater` | `default` | When `ecr_host` is set | `cluster_admin_role` |
| `Job` | ECR token updater sync hook jobs | `default` | Hook jobs associated with image mirroring | `cluster_admin_role` |
