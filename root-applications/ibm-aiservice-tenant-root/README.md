IBM AIService Tenant Root Application
===============================================================================
Installs various ArgoCD Applications for managing instance-level AIService dependencies (e.g. ODH, AIService etc) and AIService Applications (e.g. kmodel, aiservice-tenant etc) on the target cluster.

## ArgoCD Applications

The following table lists all ArgoCD applications defined in the templates folder and their rendering conditions based on admin roles:

| Template File | Application Name | Cluster Admin Role | Application Admin Role | Both Roles |
|--------------|------------------|-------------------|----------------------|------------|
| [`100-ibm-aiservice-tenant-app.yaml`](templates/100-ibm-aiservice-tenant-app.yaml) | aiservice-tenant | | | ✓ |

### Role Conditions

- **Cluster Admin Role**: Applications that require `cluster_admin_role` to be set
- **Application Admin Role**: Applications that require `application_admin_role` to be set
- **Both Roles**: Applications rendered regardless of role settings (no role condition or other conditions apply), but resources within that application are only rendered if the appropriate role is set.

**Note**: Some applications have additional conditions beyond role requirements (e.g., specific values must be defined). Refer to individual template files for complete rendering logic.