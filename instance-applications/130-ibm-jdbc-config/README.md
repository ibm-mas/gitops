IBM JDBC Configuration
===============================================================================

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
| `JdbcCfg` | MAS JDBC configuration CR | MAS core namespace | Always | `application_admin_role` |