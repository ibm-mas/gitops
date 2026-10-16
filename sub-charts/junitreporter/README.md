# Junitreporter
===============================================================================
Updates the devops database when an ArgoCD app is first synced and then marks it complete along with a JUnit XML test result.

## Overview

This sub-chart updates the DevOps tracking database at two ArgoCD sync lifecycle points: once when the application sync begins (to mark it in-progress) and again on completion (to record the JUnit XML test result and mark it done). It is used as a dependency by parent charts that require DevOps pipeline integration.

## Configuration

### Values

```yaml
junitreporter:
  # DevOps database connection URI
  devops_mongo_uri: ""
  # Build number for tracking
  devops_build_number: ""
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|---|---|---|---|---|
| `Job` | `junitreporter-presync-*` | parent namespace | PreSync hook | `cluster_admin_role` |
| `Job` | `junitreporter-postsync-*` | parent namespace | PostSync hook | `cluster_admin_role` |

## Examples

### Include as a sub-chart dependency

```yaml
# In parent chart's Chart.yaml
dependencies:
  - name: junitreporter
    version: "1.0.0"
    repository: "file://../junitreporter"
```
