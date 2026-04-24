IBM AIService Tenant Root Application
===============================================================================
Installs various ArgoCD Applications for managing instance-level AIService dependencies (e.g. ODH, AIService etc) and AIService Applications (e.g. kmodel, aiservice-tenant etc) on the target cluster.

## Table of Contents

- [ArgoCD Applications](#argocd-applications)
  - [Role Conditions](#role-conditions)

<!--docs-include-start-->

This application is part of the **App of Apps** hierarchy:

```
ibm-mas-account-root
└── ibm-mas-cluster-root
    ├── ibm-mas-instance-root
    ├── ibm-mas-sls-root
    └── ibm-aiservice-instance-root
        └── ibm-aiservice-tenant-root (this application)
```

For more information about the GitOps architecture and concepts, see:
- [GitOps Architecture](https://ibm-mas.github.io/gitops/architecture/)
- [AI Service Tenant Root Application](https://ibm-mas.github.io/gitops/charts/root-applications/#ai-service-tenant-root-application)
- [Configuration Repository](https://ibm-mas.github.io/gitops/configrepo/)
- [Helm Charts](https://ibm-mas.github.io/gitops/helmcharts/)

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