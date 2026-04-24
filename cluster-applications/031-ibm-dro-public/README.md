IBM DRO Public Route
===============================================================================
Expose the IBM Data Reporter Operator (DRO) metrics endpoint through a public OpenShift route.

<!--docs-include-start-->


This chart creates the public `Route` used to expose DRO externally when IBM Cloud Internet Services (CIS) is the configured DNS provider. It is intended to be rendered by the cluster root application template [`031-ibm-dro-public.yaml`](https://github.com/ibm-mas/gitops/tree/main/root-applications/ibm-mas-cluster-root/templates/031-ibm-dro-public.yaml).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Route` | `ibm-data-reporter-public-route` | Configured DRO namespace | When `dns_provider` is `cis` | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
cluster_id: string
dro_namespace: string
dro_public_domain: string
dro_tls_certificate: string
dro_tls_key: string
dns_provider: string
```

**Note**: This chart does not use a top-level key wrapper.

### Value descriptions

- `cluster_id`: Cluster identifier used to construct the route host as `dro.<cluster_id>.<dro_public_domain>`.
- `dro_namespace`: Namespace where the public route is created.
- `dro_public_domain`: Base public domain used for the external DRO host.
- `dro_tls_certificate`: TLS certificate content presented by the route.
- `dro_tls_key`: TLS private key associated with `dro_tls_certificate`.
- `dns_provider`: DNS provider selector. The route is created only when this is set to `cis`.

### Usage Example

```yaml
cluster_id: "cluster1"
dro_namespace: "ibm-software-central"
dro_public_domain: "example.com"
dro_tls_certificate: |
  -----BEGIN CERTIFICATE-----
  ...
  -----END CERTIFICATE-----
dro_tls_key: |
  -----BEGIN PRIVATE KEY-----
  ...
  -----END PRIVATE KEY-----
dns_provider: "cis"
```

## Behavior

When enabled, this chart creates a re-encrypt OpenShift route named `ibm-data-reporter-public-route` that targets the `ibm-data-reporter-operator-controller-manager-metrics-service` service on port `8443`.