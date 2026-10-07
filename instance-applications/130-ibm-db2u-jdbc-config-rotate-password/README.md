IBM DB2U JDBC rotate password Configuration
===============================================================================
Rotate DB2 user password

<!--docs-include-start-->
## Overview

This chart rotates the Db2u JDBC password for a MAS instance and updates the corresponding JDBC configuration in MAS and AWS Secrets Manager to ensure continued database connectivity.



## Configuration

### Values

```yaml
ibm_db2u_jdbc_config_rotate_password:
  mas_instance_id: inst1
  jdbc_config_id: system
```

## Examples

### Rotate Db2 JDBC password

```yaml
merge-key: "my-account/my-cluster/inst1"
ibm_db2u_jdbc_config_rotate_password:
  mas_instance_id: inst1
  jdbc_config_id: system
```

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | DB2U JDBC credential secret | MAS core namespace | Always | `application_admin_role` |
