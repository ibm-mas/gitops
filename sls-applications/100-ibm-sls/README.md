IBM Suite License Service
===============================================================================

## Overview

Installs the `ibm-sls` operator and creates an instance of the `LicenseService`.

Contains a job that runs last (`07-postsync-update-sm_Job.yaml`). This registers the `${ACCOUNT_ID}/${ICN}/${SAAS_SUB_ID}/sls` secret in the **Secrets Vault** used to share some information that is generated at runtime with other ArgoCD Applications.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `operatorgroup` | `mas-<icn>-<subscription_id>-sls` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Subscription` | `ibm-sls` | `mas-<icn>-<subscription_id>-sls` | When `cluster_admin_role` is true | `cluster_admin_role` |
| `Secret` | SLS entitlement, Mongo, AWS, and image pull secrets | `mas-<icn>-<subscription_id>-sls` | Application resources always when `application_admin_role` is true; hook secrets when sync hooks run | `application_admin_role` |
| `LicenseService` | `sls` | `mas-<icn>-<subscription_id>-sls` | When `application_admin_role` is true | `application_admin_role` |
| `Job` | SLS DNS and post-sync update jobs | `mas-<icn>-<subscription_id>-sls` | DNS job when `dns_provider` is set; post-sync job when `run_sync_hooks` and `application_admin_role` are true | `application_admin_role` |
| `NetworkPolicy` | `postsync-ibm-sls-update-sm-np` | `mas-<icn>-<subscription_id>-sls` | When `run_sync_hooks` and `application_admin_role` are true | `application_admin_role` |
| `ServiceAccount` | `postsync-ibm-sls-update-sm-sa` | `mas-<icn>-<subscription_id>-sls` | When `run_sync_hooks` and `application_admin_role` are true | `application_admin_role` |
| `Role` | `postsync-ibm-sls-update-sm-r` | `mas-<icn>-<subscription_id>-sls` | When `run_sync_hooks` and `application_admin_role` are true | `application_admin_role` |
| `RoleBinding` | `postsync-ibm-sls-update-sm-rb` | `mas-<icn>-<subscription_id>-sls` | When `run_sync_hooks` and `application_admin_role` are true | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_sls_standalone:
  # Identity (required)
  ibm_customer_number: string
  subscription_id: string

  # SLS Domain (required)
  sls_domain: string

  # Licensing (required)
  sls_channel: string
  sls_entitlement_file: string (secret reference)
  ibm_entitlement_key: string (secret reference)

  # MongoDB Configuration (required)
  sls_mongo_secret_name: string
  sls_mongo_username: string (secret reference)
  sls_mongo_password: string (secret reference)
  mongo_spec:
    authMechanism: string
    configDb: string
    secretName: string
    retryWrites: boolean (optional)
    nodes:
      hosts:
        - host: string
          port: number
    certificates:
      - alias: string
        crt: string (multiline)

  # Operator Configuration
  icr_cp_open: string
  sls_install_plan: string
  run_sync_hooks: boolean

  # DNS Configuration (optional)
  dns_provider: string
  cis_domain: string
  cis_crn: string

  # Pod Templates (optional)
  sls_pod_templates:
    key: value

  # Certificate Authority (optional)
  internal_certificate_authority: string
```

**Note**: Values marked with "(secret reference)" should use the format `<path:secrets/path:key>` to reference secrets stored in the Secrets Vault.

## Examples

Centralized SLS deployment with ICN:
```yaml
ibm_sls_standalone:
  ibm_customer_number: "1234567"
  subscription_id: "sub-001"
  sls_domain: "sls.example.com"
  sls_channel: "3.x"
  sls_entitlement_file: "<path:arn:aws:secretsmanager:us-east-1:xxxx:secret:account/icn/sub-001/license#license_file>"
  ibm_entitlement_key: "<path:arn:aws:secretsmanager:us-east-1:xxxx:secret:account/cluster/ibm_entitlement#image_pull_secret_b64>"
  sls_install_plan: Automatic
  sls_mongo_secret_name: sls-mongo-credentials
  sls_mongo_username: "<path:arn:aws:secretsmanager:us-east-1:xxxx:secret:account/icn/sub-001/mongo#username>"
  sls_mongo_password: "<path:arn:aws:secretsmanager:us-east-1:xxxx:secret:account/icn/sub-001/mongo#password>"
  icr_cp_open: "icr.io/cpopen"
  run_sync_hooks: true
  mongo_spec:
    authMechanism: DEFAULT
    configDb: admin
    secretName: sls-mongo-credentials
    retryWrites: false
    nodes:
      hosts:
        - host: mongo.example.com
          port: 27017
  sls_pod_templates:
    nodeSelector:
      kubernetes.io/os: linux
```
