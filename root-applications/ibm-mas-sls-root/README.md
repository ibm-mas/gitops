IBM MAS SLS Root Application
===============================================================================
Installs ArgoCD Application for managing standalone SLS instances on the target cluster.

## ArgoCD Applications

The following table lists the ArgoCD application defined in the templates folder:

| Template File | Application Name | Cluster Admin Role | Application Admin Role | Both Roles |
|--------------|------------------|-------------------|----------------------|------------|
| [`100-ibm-sls-app.yaml`](templates/100-ibm-sls-app.yaml) | sls | | | ✓ |

### Role Conditions

- **Both Roles**: This application is rendered regardless of role settings (no role condition), but resources within that application are only rendered if the appropriate role is set.

**Note**: The application requires `ibm_sls_standalone` to be defined in values. Refer to the template file for complete rendering logic.