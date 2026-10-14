IBM CIS Cert Manager
===============================================================================
Deploy and configure IBM CIS Cert Manager related resources

<!--docs-include-start-->
## Overview

This chart deploys the IBM Cloud Internet Services (CIS) webhook for cert-manager on an OpenShift cluster. When `dns_provider` is set to `"cis"`, it provisions the webhook RBAC resources, PKI certificates, operator deployment, API service registration, CIS API key secret, and an optional public ingress controller. A placeholder `ConfigMap` is always created so ArgoCD has at least one resource to track when CIS is not enabled.



## Configuration

### Values

```yaml
ibm_cis_cert_manager:
  # DNS provider for certificate management
  # Options: "cis" (IBM Cloud Internet Services) or other DNS providers
  # When set to "cis", deploys IBM CIS webhook for cert-manager
  dns_provider: ""

  # OpenShift cluster domain (required when dns_provider is "cis")
  # The base domain of your OpenShift cluster
  # Example: apps.cluster-name.example.com
  ocp_cluster_domain: ""

  # IBM Cloud API key (required when dns_provider is "cis")
  # API key with permissions to manage DNS records in IBM CIS
  cis_apikey: ""

  # Public cluster domain (optional)
  # External domain for public-facing routes
  # Example: public.example.com
  ocp_public_cluster_domain: ""

  # Enable ingress controller configuration (optional)
  # When true, creates a public IngressController
  # Default: false
  ingress: false
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

**Basic IBM CIS configuration:**
```yaml
ibm_cis_cert_manager:
  dns_provider: "cis"
  ocp_cluster_domain: "apps.prod-cluster.example.com"
  cis_apikey: "your-ibm-cloud-api-key"
```

**With public domain and ingress:**
```yaml
ibm_cis_cert_manager:
  dns_provider: "cis"
  ocp_cluster_domain: "apps.prod-cluster.example.com"
  ocp_public_cluster_domain: "public.example.com"
  cis_apikey: "your-ibm-cloud-api-key"
  ingress: true
```

**Non-CIS DNS provider:**
```yaml
ibm_cis_cert_manager:
  dns_provider: "route53"
  # CIS-specific resources will not be created
```

### Prerequisites

When using IBM CIS as the DNS provider:

1. **IBM Cloud Account** with CIS service provisioned
2. **API Key** with the following permissions:
   - DNS Records: Read, Write
   - DNS Zones: Read
3. **Domain** configured in IBM CIS
4. **cert-manager** operator installed (via redhat-cert-manager chart)

## Examples

### Minimal CIS configuration

```yaml
merge-key: "my-account/my-cluster"
ibm_cis_cert_manager:
  dns_provider: "cis"
  ocp_cluster_domain: "apps.prod-cluster.example.com"
  cis_apikey: "<path:arn:aws:secretsmanager:us-west-2:123456789012:secret:my-account/my-cluster/cis#apikey>"
```

### With public domain and ingress controller

```yaml
merge-key: "my-account/my-cluster"
ibm_cis_cert_manager:
  dns_provider: "cis"
  ocp_cluster_domain: "apps.prod-cluster.example.com"
  ocp_public_cluster_domain: "public.example.com"
  cis_apikey: "<path:arn:aws:secretsmanager:us-west-2:123456789012:secret:my-account/my-cluster/cis#apikey>"
  ingress: true
```

### Non-CIS DNS provider (placeholder only)

```yaml
merge-key: "my-account/my-cluster"
ibm_cis_cert_manager:
  dns_provider: "route53"
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | `placeholder` | `default` | Always | `cluster_admin_role` |
| `ServiceAccount` | `cert-manager-webhook-ibm-cis` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Role` | `cert-manager-webhook-ibm-cis` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `RoleBinding` | `cert-manager-webhook-ibm-cis` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `RoleBinding` | `cert-manager-webhook-ibm-cis:webhook-authentication-reader` | `kube-system` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `RoleBinding` | `system:openshift:scc:anyuid` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `ClusterRole` | `cert-manager-webhook-ibm-cis:domain-solver` | N/A (cluster-scoped) | When `dns_provider` is "cis" | `cluster_admin_role` |
| `ClusterRoleBinding` | `cert-manager-webhook-ibm-cis:domain-solver` | N/A (cluster-scoped) | When `dns_provider` is "cis" | `cluster_admin_role` |
| `ClusterRoleBinding` | `cert-manager-webhook-ibm-cis:auth-delegator` | N/A (cluster-scoped) | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Issuer` | `cert-manager-webhook-ibm-cis-self-signed-issuer` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Certificate` | `cert-manager-webhook-ibm-cis-root-ca-certificate` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Issuer` | `cert-manager-webhook-ibm-cis-root-ca-issuer` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Certificate` | `cert-manager-webhook-ibm-cis-serving-cert` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Deployment` | `cert-manager-webhook-ibm-cis` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `APIService` | `v1alpha1.acme.cis.ibm.com` | N/A (cluster-scoped) | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Service` | `cert-manager-webhook-ibm-cis` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Secret` | `cis-api-key` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Route` | `cis-proxy-route` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `IngressController` | `public` | `openshift-ingress-operator` | When `dns_provider` is "cis" and `ingress` is true | `cluster_admin_role` |
