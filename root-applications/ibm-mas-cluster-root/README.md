IBM MAS Cluster Root Application
===============================================================================
Installs various ArgoCD Applications for managing dependencies shared by MAS instances on the target cluster.

Installs the MAS Instance Root ArgoCD ApplicationSet ([`099-instance-appset.yaml`](templates/099-instance-appset.yaml)) responsible for generating a set of IBM MAS Instance Root ArgoCD Applications for managing MAS instances on the target cluster. See [README](root-applications/ibm-mas-instance-root/README.md) for more details on that application set.

Installs the AIService Instance Root ArgoCD ApplicationSet ([`099-aiservice-instance-appset.yaml`](templates/099-aiservice-instance-appset.yaml)) responsible for generating a set of IBM AIService Instance Root ArgoCD Applications for managing AIService instances on the target cluster. See [README](root-applications/ibm-aiservice-instance-root/README.md) for more details on that application set.

Installs the SLS Root ArgoCD ApplicationSet ([`065-sls-appset.yaml`](templates/065-sls-appset.yaml)) responsible for generating a set of SLS Instance Root ArgoCD Applications for managing standalone SLS instances on the target cluster. See [README](root-applications/ibm-mas-sls-root/README.md) for more details on that application set.

## ArgoCD Applications

The following table lists all ArgoCD applications and ApplicationSets defined in the templates folder and their rendering conditions based on admin roles:

| Template File | Application Name | Cluster Admin Role | Application Admin Role | Both Roles |
|--------------|------------------|-------------------|----------------------|------------|
| [`000-efs-csi-driver.yaml`](templates/000-efs-csi-driver.yaml) | efs-csi-driver | ✓ | | |
| [`000-ibm-operator-catalog-app.yaml`](templates/000-ibm-operator-catalog-app.yaml) | operator-catalog | ✓ | | |
| [`000-image-mirroring.yaml`](templates/000-image-mirroring.yaml) | image-mirroring | ✓ | | |
| [`000-job-cleaner.yaml`](templates/000-job-cleaner.yaml) | job-cleaner | ✓ | | |
| [`010-ibm-redhat-cert-manager-app.yaml`](templates/010-ibm-redhat-cert-manager-app.yaml) | redhat-cert-manager | ✓ | | |
| [`020-ibm-dro-app.yaml`](templates/020-ibm-dro-app.yaml) | dro | ✓ | | |
| [`021-ibm-dro-cleanup.yaml`](templates/021-ibm-dro-cleanup.yaml) | ibm-dro-cleanup | ✓ | | |
| [`030-ibm-cis-cert-manager.yaml`](templates/030-ibm-cis-cert-manager.yaml) | ibm-cis-cert-manager | ✓ | | |
| [`040-cis-compliance-app.yaml`](templates/040-cis-compliance-app.yaml) | cis-compliance | ✓ | | |
| [`041-cis-compliance-cleanup.yaml`](templates/041-cis-compliance-cleanup.yaml) | cis-compliance-cleanup | ✓ | | |
| [`050-nfd-operator-app.yaml`](templates/050-nfd-operator-app.yaml) | nfd | ✓ | | |
| [`051-nvidia-gpu-operator-app.yaml`](templates/051-nvidia-gpu-operator-app.yaml) | nvidia-gpu | ✓ | | |
| [`052-group-sync-operator-app.yaml`](templates/052-group-sync-operator-app.yaml) | group-sync-operator | ✓ | | |
| [`053-falcon-operator-app.yaml`](templates/053-falcon-operator-app.yaml) | falcon-operator | ✓ | | |
| [`054-cluster-logging-operator-app.yaml`](templates/054-cluster-logging-operator-app.yaml) | cluster-logging-operator | ✓ | | |
| [`055-instana-agent-operator-app.yaml`](templates/055-instana-agent-operator-app.yaml) | instana-agent-operator | ✓ | | |
| [`060-custom-sa.yaml`](templates/060-custom-sa.yaml) | custom-sa | ✓ | | |
| [`060-selenium-grid.yaml`](templates/060-selenium-grid.yaml) | selenium-grid | ✓ | | |
| [`061-ibm-rbac-app.yaml`](templates/061-ibm-rbac-app.yaml) | ibm-rbac | ✓ | | |
| [`065-sls-appset.yaml`](templates/065-sls-appset.yaml) | sls-appset (ApplicationSet) | ✓ | | |
| [`099-aiservice-instance-appset.yaml`](templates/099-aiservice-instance-appset.yaml) | aiservice-instance-appset (ApplicationSet) | | | ✓ |
| [`099-instance-appset.yaml`](templates/099-instance-appset.yaml) | instance-appset (ApplicationSet) | | | ✓ |
| [`200-cluster-promotion-app.yaml`](templates/200-cluster-promotion-app.yaml) | cluster-promotion | ✓ | | |
| [`300-mas-provisioner-app.yaml`](templates/300-mas-provisioner-app.yaml) | mas-provisioner | ✓ | | |

### Role Conditions

- **Cluster Admin Role**: Applications that require `cluster_admin_role` to be set (21 applications)
- **Both Roles**: Applications/ApplicationSets rendered regardless of role settings (2 ApplicationSets)

**Note**: Most applications have additional conditions beyond role requirements (e.g., specific values must be defined). Refer to individual template files for complete rendering logic.