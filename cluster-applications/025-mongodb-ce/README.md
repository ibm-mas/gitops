# MongoDB Community Operator and Instance Chart
=============================================
This chart installs the MongoDB Community Operator, deploys a MongoDB Community replica set, and automatically registers MongoDB connection details and credentials into AWS Secrets Manager so that SLS (and MAS) can consume them.

<!--docs-include-start-->

## Overview

This chart provisions a MongoDB Community Operator and a 3-node MongoDB Community replica set within the specified namespace (default: `mongoce`). It creates the necessary operator group, subscriptions, admin credential secrets, and stateful replica set. Additionally, it executes a post-sync job that automatically formats and pushes connection details, credentials, and TLS certificates to AWS Secrets Manager (`${ACCOUNT_ID}/${CLUSTER_ID}/mongo`) for seamless integration with IBM SLS and MAS.

## Prerequisites

- OpenShift Cluster 4.12+
- `community-operators` CatalogSource enabled in `openshift-marketplace`
- ArgoCD / OpenShift GitOps with Cluster Admin privileges
- AWS Secrets Manager access credentials configured in the cluster environment

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|---|---|---|---|---|
| `Namespace` | `mongoce` | - | Always | `cluster_admin_role` |
| `OperatorGroup` | `mongodb-operator-group` | `mongoce` | Always | `cluster_admin_role` |
| `Subscription` | `mongodb-kubernetes-operator` | `mongoce` | Always | `cluster_admin_role` |
| `Secret` | `admin-user-credentials` | `mongoce` | Always | `cluster_admin_role` |
| `MongoDBCommunity` | `mas-mongo-ce` | `mongoce` | Always | `cluster_admin_role` |
| `Secret` | `mongo-aws-creds` | `mongoce` | When `run_sync_hooks` and `cluster_admin_role` | `cluster_admin_role` |
| `Job` | `postsync-mongo-update-sm-job-*` | `mongoce` | When `run_sync_hooks` and `cluster_admin_role` | `cluster_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
mongodb_ce:
  install: "true"
  channel: "v0.7"
  install_plan: "Automatic"
  source: "community-operators"
  source_namespace: "openshift-marketplace"
  namespace: "mongoce"
  instance_name: "mas-mongo-ce"
  version: "7.0.5"
  members: 3
  admin_password: "<path:secret#password>"
  storage_size: "10Gi"
  storage_class: ""
```

## Base Cluster Values

This chart inherits common cluster configuration values. For complete documentation of all base cluster values including optional fields like `notifications`, `custom_labels`, `devops`, and `cli_image_repo`, see the [Cluster Base Values Reference](../../docs/reference/cluster-base-values.md).

## Examples

### Basic MongoDB Community Deployment

```yaml
merge-key: "my-account/my-cluster"
mongodb_ce:
  install: "true"
  members: 3
  version: "7.0.5"
  storage_size: "10Gi"
  admin_password: "<path:arn:aws:secretsmanager:us-west-2:123456789:secret:my-account/my-cluster/mongo#password>"
```

### Secrets Manager Integration

Upon successful deployment of the MongoDB replica set, the post-sync Job creates / updates the cluster secret at:
`${ACCOUNT_ID}/${CLUSTER_ID}/mongo`

With the following JSON payload:
```json
{
  "docdb_host": "mas-mongo-ce-0.mas-mongo-ce-svc.mongoce.svc.cluster.local",
  "docdb_port": "27017",
  "username": "admin",
  "password": "<admin_password>",
  "info": "config:\n  hosts:\n    - host: mas-mongo-ce-0.mas-mongo-ce-svc.mongoce.svc.cluster.local\n      port: 27017\n    - host: mas-mongo-ce-1.mas-mongo-ce-svc.mongoce.svc.cluster.local\n      port: 27017\n    - host: mas-mongo-ce-2.mas-mongo-ce-svc.mongoce.svc.cluster.local\n      port: 27017\n  configDb: admin\n  authMechanism: DEFAULT\n"
}
```

## Troubleshooting

- **MongoDBCommunity CR not ready**: Verify that the operator pod in `mongoce` is running without OOM or storage binding errors.
- **Post-sync Job failure**: Check the Job pod logs in `mongoce` namespace to verify AWS credentials and secret permissions.

## Related Documentation

- [Cluster Base Values Reference](../../docs/reference/cluster-base-values.md)
- [IBM SLS Application Documentation](../../sls-applications/100-ibm-sls/README.md)
