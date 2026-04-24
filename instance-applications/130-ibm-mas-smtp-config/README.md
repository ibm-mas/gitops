SMTP Configuration for MAS Core Platform
===============================================================================
Create a SmtpCfg CR instance and associated credentials secret for use by MAS.

<!--docs-include-start-->


Contains a post-delete hook (`postdelete-delete-cr.yaml`) that will ensure the config CR is deleted when the ArgoCD application managing this chart is deleted (this will not happen by default as the config CR is asserted to be owned by the `Suite` CR by the MAS entity managers).

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | SMTP credential secret | MAS core namespace | Always | `application_admin_role` |
| `SmtpCfg` | MAS SMTP configuration CR | MAS core namespace | Always | `application_admin_role` |
| `Job` | Post-delete SMTP configuration cleanup job | MAS core namespace | When `use_postdelete_hooks` is enabled | `application_admin_role` |

## Configuration

This chart accepts the following configuration values in the ArgoCD Application values:

```yaml
mas_config_name: string
mas_config_chart: string
mas_config_scope: string
mas_workspace_id: string
mas_application_id: string
mas_config_kind: string
mas_config_api_version: string
use_postdelete_hooks: boolean

suite_smtp_username: string (secret reference)
suite_smtp_password: string (secret reference)
suite_smtp_display_name: string
suite_smtp_host: string
suite_smtp_port: string
suite_smtp_security: string
suite_smtp_authentication: string
suite_smtp_default_sender_email: string
suite_smtp_default_sender_name: string
suite_smtp_default_recipient_email: string
suite_smtp_default_should_email_passwords: string

# Pod Templates (optional)
mas_smtpcfg_pod_templates:
  key: value

# Disabled Templates (optional)
suite_smtp_disabled_templates: string

# CA Certificate (optional)
smtp_config_ca_certificate:
  crt: string (multiline)
```

**Note**: Values marked with "(secret reference)" should use the format `<path:secrets/path:key>` to reference secrets stored in the Secrets Vault. This chart does not use a top-level key wrapper.

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
