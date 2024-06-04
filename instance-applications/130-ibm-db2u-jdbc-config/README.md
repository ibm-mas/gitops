IBM DB2U JDBC Configuration
===============================================================================
Provide MAS with JDBC config for a DB2u database.

Contains a pre-sync hook (`00-presync-create-db2-user_Job.yaml`) that set up an LDAP user in DB2 with the credentials provided in the JDBC config. 

Contains a post-delete hook (`postdelete-delete-cr.yaml`) that will ensure the config CR is deleted when the ArgoCD application managing this chart is deleted (this will not happen by default as the config CR is asserted to be owned by the `Suite` CR by the MAS entity managers).