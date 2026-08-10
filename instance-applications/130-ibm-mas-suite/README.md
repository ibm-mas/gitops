MAS Core Platform
===============================================================================
Installs the `ibm-mas` operator and creates an instance of the `Suite`.

<!--docs-include-start-->


## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `ClusterIssuer` | IBM CIS cluster issuers | N/A (cluster-scoped) | When CIS integration is enabled | `application_admin_role` |
| `OperatorGroup` | IBM MAS operator group | MAS core namespace | Always | `application_admin_role` |
| `Secret` | Suite certificate and entitlement secrets | MAS core namespace | Always | `application_admin_role` |
| `Subscription` | IBM MAS operator subscription | MAS core namespace | Always | `application_admin_role` |
| `Suite` | MAS Suite CR | MAS core namespace | Always | `application_admin_role` |
| `NetworkPolicy` | Post-sync and post-delete job network policies | MAS core namespace | When associated jobs are enabled | `application_admin_role` |
| `ServiceAccount` | Post-sync and post-delete job service accounts | MAS core namespace | When associated jobs are enabled | `application_admin_role` |
| `Role` | Post-sync and post-delete job roles | MAS core namespace | When associated jobs are enabled | `application_admin_role` |
| `RoleBinding` | Post-sync and post-delete job role bindings | MAS core namespace | When associated jobs are enabled | `application_admin_role` |
| `Job` | Post-sync suite configuration jobs | MAS core namespace | When associated jobs are enabled | `application_admin_role` |
| `ConfigMap` | Suite helper and runtime configuration config maps | MAS core namespace | When associated jobs or certificate management features are enabled | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
ibm_mas_suite:
  cert_manager_namespace: string
  ibm_entitlement_key: string (secret reference)
  domain: string
  mas_feature_usage: string
  mas_deployment_progression: string
  mas_usability_metrics: string
  
  # DNS Configuration (optional)
  dns_provider: string
  mas_workspace_id: string
  mas_config_dir: string
  mas_domain: string
  ocp_cluster_domain: string
  
  # CIS Configuration (optional, when dns_provider is 'cis')
  cis_mas_domain: string
  cis_subdomain: string
  cis_email: string
  cis_crn: string
  cis_apikey: string (secret reference)
  cis_enhanced_security: string
  cis_proxy: string
  cis_waf: string
  cis_service_name: string
  update_dns_entries: string
  delete_wildcards: string
  override_edge_certs: string
  
  # Operator Configuration
  mas_channel: string
  mas_install_plan: string
  icr_cp: string
  icr_cp_open: string
  
  # Certificate Management
  mas_manual_cert_mgmt: boolean
  routing_mode: string (optional)
  ingress_controller_name: string (optional)
  
  # Annotations and Labels (optional)
  mas_annotations:
    key: value
  mas_labels:
    key: value
  mas_image_tags:
    key: value
  
  # Manual Certificates (optional)
  ca_cert: string
  tls_cert: string
  tls_key: string
  manual_certs:
    key: value
  
  # Pod Templates (optional)
  mas_pod_templates:
    key: value
  
  # OIDC Configuration (optional)
  oidc:
    key: value
  
  # Additional Configuration (optional)
  allow_list: string
  suite_spec_additional_properties:
    key: value
  suite_spec_settings_additional_properties:
    key: value
  internal_certificate_authority: string
  welcome_message: string (multiline)
```

**Note**: Values marked with "(secret reference)" should use the format `<path:secrets/path:key>` to reference secrets stored in the Secrets Vault.

## Base Instance Values

This chart inherits common instance configuration values. The most frequently used base values are:

```yaml
account:
  id: string                    # Account identifier
  name: string                  # Account name

region:
  id: string                    # Region identifier
  name: string                  # Region name

cluster:
  id: string                    # Cluster identifier
  name: string                  # Cluster name

instance:
  id: string                    # MAS instance identifier

sm:                             # Secrets Manager configuration
  aws_secret_region: string
  aws_access_key_id: string (secret reference)
  aws_secret_access_key: string (secret reference)
```

For complete documentation of all base instance values including optional fields like `custom_labels`, `argocluster_instance`, `application_admin_service_account`, `mas_wipe_mongo_data`, `allow_list`, `additional_vpn`, `application_configuration`, `use_postdelete_hooks`, `additional_resources`, `extensions`, `enhanced_dr`, and `cli_image_repo`, see the [Instance Base Values Reference](../../docs/reference/instance-base-values.md).
