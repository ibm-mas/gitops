IBM AIService Instance Root Application
===============================================================================
Installs various ArgoCD Applications for managing instance-level AIService dependencies (e.g. ODH etc) and AIService Applications (e.g. kmodel, aiservice-tenant etc) on the target cluster.

Installs the AIService Tenant Root ArgoCD ApplicationSet ([`070-aiservice-tenant-appset.yaml`](templates/070-aiservice-tenant-appset.yaml)) responsible for generating a set of IBM AIService Tenant Root ArgoCD Applications for managing AIService Tenants of a AIService Instance on the target cluster. See [README](root-applications/ibm-aiservice-tenant-root/README.md) for more details on that application set.

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
    └── ibm-aiservice-instance-root (this application)
        └── ibm-aiservice-tenant-root
```

For more information about the GitOps architecture and concepts, see:
- [GitOps Architecture](https://ibm-mas.github.io/gitops/architecture/)
- [AI Service Instance Root Application](https://ibm-mas.github.io/gitops/charts/root-applications/#ai-service-instance-root-application)
- [Configuration Repository](https://ibm-mas.github.io/gitops/configrepo/)
- [Helm Charts](https://ibm-mas.github.io/gitops/helmcharts/)

## ArgoCD Applications

The following table lists all ArgoCD applications defined in the templates folder and their rendering conditions based on admin roles:

| Template File | Application Name | Cluster Admin Role | Application Admin Role | Both Roles |
|--------------|------------------|-------------------|----------------------|------------|
| [`030-ibm-odh-app.yaml`](templates/030-ibm-odh-app.yaml) | odh | | | ✓ |
| [`031-ibm-rhoai-app.yaml`](templates/031-ibm-rhoai-app.yaml) | rhoai | | | ✓ |
| [`040-ibm-aiservice-app.yaml`](templates/040-ibm-aiservice-app.yaml) | aiservice | | | ✓ |
| [`070-aiservice-tenant-appset.yaml`](templates/070-aiservice-tenant-appset.yaml) | ai-tenant-appset (ApplicationSet) | | | ✓ |

### Role Conditions

- **Cluster Admin Role**: Applications that require `cluster_admin_role` to be set
- **Application Admin Role**: Applications that require `application_admin_role` to be set
- **Both Roles**: Applications rendered regardless of role settings (no role condition or other conditions apply), but resources within that application are only rendered if the appropriate role is set.

**Note**: Some applications have additional conditions beyond role requirements (e.g., specific values must be defined). Refer to individual template files for complete rendering logic.