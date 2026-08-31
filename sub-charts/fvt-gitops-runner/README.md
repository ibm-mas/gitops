# fvt-gitops-runner

Helm sub-chart that runs the SaaS GitOps test suite as an ArgoCD **PostSync** Kubernetes Job.

## Overview

The `fvt-gitops-runner` sub-chart is included as a dependency in the `600-ibm-post-sync-jobs` chart.
When enabled it creates a PostSync `Job` that executes the `fvt-gitops` test image against the
deployed MAS instance immediately after every successful ArgoCD sync.

The tests are non-side-effecting (read-only) and verify that all GitOps-deployed features are
fully deployed and functioning as expected.  Results are written to MongoDB using the standard
`ibm-mas-gitops` product schema (`masfvt.runsv2` / `masfvt.resultsv2`).

## Configuration

| Parameter | Description | Default |
|---|---|---|
| `enabled` | Enable the test runner Job | `false` |
| `instance_id` | MAS instance ID | `""` |
| `workspace_id` | MAS workspace ID | `"masdev"` |
| `test_suite` | Test suite to run (`suite` \| `manage` \| `cluster`) | `"suite"` |
| `gitops_version` | GitOps chart version written to MongoDB for traceability | `""` |
| `devops_build_number` | Build/run identifier written to MongoDB | `""` |
| `devops_mongo_uri` | MongoDB connection string; leave empty to skip result recording | `""` |
| `fvt_gitops_image_repo` | Container image repository for the `fvt-gitops` test image | `docker-na-public.artifactory.swg-devops.com/wiotp-docker-local/mas-devops/fvt-gitops` |
| `fvt_gitops_image_tag` | Container image tag | `"latest"` |
| `argo_namespace` | ArgoCD namespace | `"openshift-gitops"` |
| `custom_labels` | Extra labels applied to all created resources | `{}` |

## Resources Created

When `enabled: true` the following Kubernetes resources are created in the namespace of the
parent ArgoCD Application (typically `mas-<instance_id>-postsyncjobs`):

| Resource | Name pattern | Purpose |
|---|---|---|
| `NetworkPolicy` | `fvt-gitops-<suite>-np` | Allow egress from the Job pod (MongoDB + cluster API) |
| `Secret` | `fvt-gitops-<suite>-devopsuri` | MongoDB URI injected at runtime |
| `ServiceAccount` | `fvt-gitops-<suite>-sa` | Identity for the Job pod |
| `Role` | `fvt-gitops-<suite>-role` | Read-only access to MAS CRs, pods, ArgoCD Applications, CatalogSources |
| `RoleBinding` | `fvt-gitops-<suite>-rb` | Binds the Role to the ServiceAccount |
| `Job` | `fvt-gitops-<suite>-job` | PostSync Job that runs the test suite |

All resources carry `argocd.argoproj.io/hook: PostSync` and
`argocd.argoproj.io/hook-delete-policy: HookSucceeded,BeforeHookCreation` so they are
automatically cleaned up after a successful run.

## Examples

### Enable the full GitOps test suite

```yaml
fvt_gitops:
  enabled: true
  test_suite: "suite"
  image_tag: "1.2.3"

devops:
  mongo_uri: "<path:arn:aws:secretsmanager:us-east-1:123456789:secret:mongo#uri>"
  build_number: "9.1.0-250601"
```

### Enable only the Manage sub-suite

```yaml
fvt_gitops:
  enabled: true
  test_suite: "manage"
  image_tag: "latest"
```

### Trigger scenarios

| Trigger | Recommended `test_suite` |
|---|---|
| Complete managed build | `suite` |
| Manage-only change | `manage` |
| Cluster-level change | `cluster` |

## Prerequisites

- A running MAS instance managed by this GitOps repo.
- The `fvt-gitops` Docker image must be published and accessible from the cluster.
- MongoDB (`devops.mongo_uri`) must be set to persist test results; if omitted results are printed to the Job log only.

## Troubleshooting

- **Job fails with `Unknown suite`** — verify `test_suite` matches a directory available in the `fvt-gitops` image (`suite`, `manage`, `cluster`).
- **No results in MongoDB** — ensure `devops_mongo_uri` is populated and the `NetworkPolicy` egress rule allows outbound traffic to the MongoDB endpoint.
- **Image pull errors** — confirm `fvt_gitops_image_repo` / `fvt_gitops_image_tag` point to a valid, accessible image and that an appropriate `imagePullSecret` is configured on the cluster if the registry is private.

## Related Documentation

- [fvt-gitops repository](https://github.com/ibm-mas/fvt-gitops)
- [600-ibm-post-sync-jobs chart](../../instance-applications/600-ibm-post-sync-jobs/README.md)
- [junitreporter sub-chart](../junitreporter/README.md)
