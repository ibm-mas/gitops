IBM JDBC Configuration
===============================================================================

Create a JdbcCfg CR instance and associated credentials secret for use by MAS.

Contains a post-delete hook (`postdelete-delete-cr.yaml`) that will ensure the config CR is deleted when the ArgoCD application managing this chart is deleted (this will not happen by default as the config CR is asserted to be owned by the `Suite` CR by the MAS entity managers).

If using incluster-db2, a pre-sync hook (`00-presync-create-db2-user_Job.yaml`) will run that sets up an LDAP user in DB2 with the credentials provided in the JDBC config. 