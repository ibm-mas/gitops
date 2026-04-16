IBM MAS Account Root Application
===============================================================================
Installs the Cluster Root ArgoCD ApplicationSet [`000-cluster-appset.yaml`]((templates/000-cluster-appset.yaml)) responsible for generating a set of IBM MAS Cluster Root ArgoCD Applications. See [README](root-applications/ibm-mas-cluster-root/README.md) for more details on that application set.

## ArgoCD Applications

The following table lists all ArgoCD applications defined in the templates folder and their rendering conditions based on admin roles:

| Template File | Application Name | Cluster Admin Role | Application Admin Role | Both Roles |
|--------------|------------------|-------------------|----------------------|------------|
| [`000-cluster-appset.yaml`](templates/000-cluster-appset.yaml) | cluster-appset (ApplicationSet) | | | ✓ |

### Role Conditions

- **Cluster Admin Role**: Applications that require `cluster_admin_role` to be set
- **Application Admin Role**: Applications that require `application_admin_role` to be set
- **Both Roles**: Applications rendered regardless of role settings (no role condition or other conditions apply), but resources within that application are only rendered if the appropriate role is set.

**Note**: Some applications have additional conditions beyond role requirements (e.g., specific values must be defined). Refer to individual template files for complete rendering logic.