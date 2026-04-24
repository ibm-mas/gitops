IBM DB2U
===============================================================================
Deploy and configure db2 operator with configurable version

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | DB2 registry pull secret | DB2 operator namespace | Always | `application_admin_role` |
| `OperatorGroup` | DB2 operator group | DB2 operator namespace | Always | `application_admin_role` |
| `Subscription` | DB2 operator subscription | DB2 operator namespace | Always | `application_admin_role` |
| `Issuer` | DB2 CA issuer resources | DB2 operator namespace | Always | `application_admin_role` |
| `Certificate` | DB2 CA certificate resources | DB2 operator namespace | Always | `application_admin_role` |