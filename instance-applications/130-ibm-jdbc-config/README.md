IBM JDBC Configuration
===============================================================================


<!--docs-include-start-->

Create a JdbcCfg CR instance and associated credentials secret for use by MAS.

Contains a post-delete hook (`postdelete-delete-cr.yaml`) that will ensure the config CR is deleted when the ArgoCD application managing this chart is deleted (this will not happen by default as the config CR is asserted to be owned by the `Suite` CR by the MAS entity managers).

If using incluster-db2, a pre-sync hook (`00-presync-create-db2-user_Job.yaml`) will run that sets up an LDAP user in DB2 with the credentials provided in the JDBC config. 

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | JDBC credential and pre-sync runtime secrets | MAS core namespace and database namespaces | Always | `application_admin_role` |
| `ServiceAccount` | DB2 user management service accounts | MAS core namespace | When DB2 user management hooks run | `application_admin_role` |
| `Role` | DB2 user management roles | MAS core namespace and database namespaces | When DB2 user management hooks run | `application_admin_role` |
| `RoleBinding` | DB2 user management role bindings | Database namespaces | When DB2 user management hooks run | `application_admin_role` |
| `NetworkPolicy` | DB2/RDS user management network policies | MAS core namespace | When pre-sync user management jobs run | `application_admin_role` |
| `Job` | Pre-sync and post-delete JDBC management jobs | MAS core namespace | Always | `application_admin_role` |

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

jdbc_type: string
jdbc_instance_name: string (or secret reference)
jdbc_instance_username: string (secret reference)
jdbc_instance_password: string (secret reference)
mas_config_dir: string
jdbc_connection_url: string (secret reference)
jdbc_route: string

# For incluster-db2 type
db2_dbname: string (secret reference, optional)
db2_namespace: string (secret reference, optional)

# Label configurations
app_suite_jdbccfg_labels:
  mas.ibm.com/applicationId: string
  mas.ibm.com/configScope: string
  mas.ibm.com/instanceId: string

system_suite_jdbccfg_labels:
  mas.ibm.com/configScope: string
  mas.ibm.com/instanceId: string

ws_suite_jdbccfg_labels:
  mas.ibm.com/configScope: string
  mas.ibm.com/instanceId: string
  mas.ibm.com/workspaceId: string

wsapp_suite_jdbccfg_labels:
  mas.ibm.com/applicationId: string
  mas.ibm.com/configScope: string
  mas.ibm.com/instanceId: string
  mas.ibm.com/workspaceId: string

jdbc_ca_pem:
  crt: string (multiline, base64 decoded from secret)
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
