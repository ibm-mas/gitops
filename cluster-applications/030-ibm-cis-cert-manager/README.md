IBM CIS Cert Manager
===============================================================================
Deploy and configure IBM CIS Cert Manager related resources

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ConfigMap` | `placeholder` | `default` | Always | `cluster_admin_role` |
| `ServiceAccount` | `cert-manager-webhook-ibm-cis` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `RoleBinding` | `cert-manager-webhook-ibm-cis:webhook-authentication-reader` | `kube-system` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `ClusterRole` | `cert-manager-webhook-ibm-cis:domain-solver` | N/A (cluster-scoped) | When `dns_provider` is "cis" | `cluster_admin_role` |
| `ClusterRoleBinding` | `cert-manager-webhook-ibm-cis:domain-solver` | N/A (cluster-scoped) | When `dns_provider` is "cis" | `cluster_admin_role` |
| `ClusterRoleBinding` | `cert-manager-webhook-ibm-cis:auth-delegator` | N/A (cluster-scoped) | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Certificate` | `cert-manager-webhook-ibm-cis-ca` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Certificate` | `cert-manager-webhook-ibm-cis-webhook-tls` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Issuer` | `cert-manager-webhook-ibm-cis-ca` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Issuer` | `cert-manager-webhook-ibm-cis-selfsign` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Deployment` | `cert-manager-webhook-ibm-cis` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `APIService` | `v1alpha1.acme.cis.ibm.com` | N/A (cluster-scoped) | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Service` | `cert-manager-webhook-ibm-cis` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Secret` | `ibm-cis-api-key` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `Route` | `cis-proxy` | `cert-manager` | When `dns_provider` is "cis" | `cluster_admin_role` |
| `IngressController` | `public` | `openshift-ingress-operator` | When `dns_provider` is "cis" and `ingress` is true | `cluster_admin_role` |