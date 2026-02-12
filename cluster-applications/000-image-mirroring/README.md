MAS Image Mirroring
===============================================================================

Establishes resources necessary to support image mirroring via an ImageDigestMirrorSet:

- `ecr-token-rotator` CronJob that rotates the ECR login token and injects it into the global pull-secret.
- `mas-ecr` `ImageDigestMirrorSet` that redirects all image pulls from icr.io and cp.icr.io to ECR

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