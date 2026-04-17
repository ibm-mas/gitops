IBM MAS Instance Root Application
===============================================================================
Installs various ArgoCD Applications for managing instance-level MAS dependencies (e.g. SLS, DB2 Databases), MAS Core and MAS Applications (e.g. Manage, Monitor, etc) on the target cluster.

## ArgoCD Applications

The following table lists all ArgoCD applications defined in the templates folder and their rendering conditions based on admin roles:

| Template File | Application Name | Cluster Admin Role | Application Admin Role | Both Roles |
|--------------|------------------|-------------------|----------------------|------------|
| [`000-ibm-sync-resources.yaml`](templates/000-ibm-sync-resources.yaml) | syncres | | | ✓ |
| [`010-ibm-sync-jobs.yaml`](templates/010-ibm-sync-jobs.yaml) | syncjobs | | | ✓ |
| [`100-ibm-sls-app.yaml`](templates/100-ibm-sls-app.yaml) | sls | | | ✓ |
| [`101-ibm-sync-jobs-cp4d.yaml`](templates/101-ibm-sync-jobs-cp4d.yaml) | syncjobs.cp4d | ✓ | | |
| [`110-ibm-cp4d-app.yaml`](templates/110-ibm-cp4d-app.yaml) | cp4d | ✓ | | |
| [`110-ibm-cp4d-operator-app.yaml`](templates/110-ibm-cp4d-operator-app.yaml) | cp4doperator | ✓ | | |
| [`110-ibm-cs-control-app.yaml`](templates/110-ibm-cs-control-app.yaml) | cscontrol | ✓ | | |
| [`110-ibm-db2u-app.yaml`](templates/110-ibm-db2u-app.yaml) | db2u | ✓ | | |
| [`120-db2-databases-app.yaml`](templates/120-db2-databases-app.yaml) | db2-db | | ✓ | |
| [`120-dbs-rds-databases-app.yaml`](templates/120-dbs-rds-databases-app.yaml) | dbs-rds-db | | | ✓ |
| [`120-ibm-spark-app.yaml`](templates/120-ibm-spark-app.yaml) | spark | ✓ | | |
| [`120-ibm-spss-app.yaml`](templates/120-ibm-spss-app.yaml) | spss | ✓ | | |
| [`120-ibm-wml-app.yaml`](templates/120-ibm-wml-app.yaml) | wml | ✓ | | |
| [`120-ibm-wsl-app.yaml`](templates/120-ibm-wsl-app.yaml) | wsl | ✓ | | |
| [`121-ibm-post-sync-job-cp4d-services.yaml`](templates/121-ibm-post-sync-job-cp4d-services.yaml) | postsyncjobs.cp4dservices | ✓ | | |
| [`130-ibm-mas-suite-app.yaml`](templates/130-ibm-mas-suite-app.yaml) | suite | | | ✓ |
| [`130-ibm-mas-suite-configs-app.yaml`](templates/130-ibm-mas-suite-configs-app.yaml) | mas_config_name | | ✓ | |
| [`200-ibm-mas-workspaces.yaml`](templates/200-ibm-mas-workspaces.yaml) | workspace | | ✓ | |
| [`500-ibm-mas-masapp-manage-install.yaml`](templates/500-ibm-mas-masapp-manage-install.yaml) | manage | | | ✓ |
| [`510-550-ibm-mas-masapp-configs.yaml`](templates/510-550-ibm-mas-masapp-configs.yaml) | masapp-config | | ✓ | |
| [`510-ibm-mas-masapp-assist-install.yaml`](templates/510-ibm-mas-masapp-assist-install.yaml) | assist | | | ✓ |
| [`505-ibm-mas-masapp-facilities-install.yaml`](templates/505-ibm-mas-masapp-facilities-install.yaml) | facilities | | | ✓ |
| [`600-application-admin-rbac-app.yaml`](templates/600-application-admin-rbac-app.yaml) | application-admin-rbac | | ✓ | |
| [`510-ibm-mas-masapp-iot-install.yaml`](templates/510-ibm-mas-masapp-iot-install.yaml) | iot | | | ✓ |
| [`510-ibm-mas-masapp-visualinspection-install.yaml`](templates/510-ibm-mas-masapp-visualinspection-install.yaml) | visualinspection | | | ✓ |
| [`520-ibm-mas-masapp-health-install.yaml`](templates/520-ibm-mas-masapp-health-install.yaml) | health | | | ✓ |
| [`520-ibm-mas-masapp-monitor-install.yaml`](templates/520-ibm-mas-masapp-monitor-install.yaml) | monitor | | | ✓ |
| [`520-ibm-mas-masapp-optimizer-install.yaml`](templates/520-ibm-mas-masapp-optimizer-install.yaml) | optimizer | | | ✓ |
| [`540-ibm-mas-masapp-predict-install.yaml`](templates/540-ibm-mas-masapp-predict-install.yaml) | predict | | | ✓ |
| [`550-ibm-mas-addons-config.yaml`](templates/550-ibm-mas-addons-config.yaml) | addons | | ✓ | |
| [`600-ibm-post-sync-jobs.yaml`](templates/600-ibm-post-sync-jobs.yaml) | postsyncjobs | | | ✓ |

### Role Conditions

- **Cluster Admin Role**: Applications that require `cluster_admin_role` to be set
- **Application Admin Role**: Applications that require `application_admin_role` to be set
- **Both Roles**: Applications rendered regardless of role settings (no role condition or other conditions apply), but resources within that application are only rendered if the appropriate role is set.

**Note**: Some applications have additional conditions beyond role requirements (e.g., specific values must be defined). Refer to individual template files for complete rendering logic.