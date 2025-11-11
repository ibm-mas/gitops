IBM DB2U Database
===============================================================================
Create a Db2u database for a MAS app.

Contains a presync hook (`00-presync-await-crd_Job.yaml`) that ensures we wait for the db2uclusters CRD to be installed before attempting to sync.

Contains a job that runs last (`05-postsync-setup-db2_Job.yaml`). This registers the `${ACCOUNT_ID}/${CLUSTER_ID}/${MAS_INSTANCE_ID}/db2/${DB2_INSTANCE_NAME}/config` secret in the **Secrets Vault** used to share some information that is generated at runtime with other ArgoCD Applications. This job also performs some special configuration steps that are required if the Db2u database is intended for use by the Manage MAS Application.
