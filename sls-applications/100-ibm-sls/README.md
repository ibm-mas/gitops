IBM Suite License Service
===============================================================================
Installs the `ibm-sls` operator and creates an instance of the `LicenseService`.

Contains a job that runs last (`07-postsync-update-sm_Job.yaml`). This registers the `${ACCOUNT_ID}/${ICN}/${SAAS_SUB_ID}/sls` secret in the **Secrets Vault** used to share some information that is generated at runtime with other ArgoCD Applications.