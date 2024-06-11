Source Repository
===============================================================================

The [ibm-mas/gitops](https://github.com/ibm-mas/gitops) repository provides Helm Charts that define all of the Kubernetes resources required to deploy MAS instances using ArgoCD. The Helm Charts are split across three sub directories, depending on their intended target:

- Helm Charts under `root-applications` contain templates that define other ArgoCD Applications and Application Sets and target the cluster (and namespace) on which ArgoCD is running.
- Helm Charts under `cluster-applications` contain templates that define Kubernetes resources for installing cluster-wide MAS pre-requisites on **Target Clusters**
- Helm Charts under `instance-applications` contain templates that define Kubernetes resources for installing one or more MAS instances on **Target Clusters**.


Application Structure
-------------------------------------------------------------------------------

The following figure shows a tree of ArgoCD applications and Application Sets defined by the Helm Charts under `root-applications`, starting with the **Account Root Application** at the top:

![Application Structure](png/appstructure.png)

The **Account Root Application** [Helm Chart](root-applications/ibm-mas-account-root) installs the **[Cluster Root Application Set](root-applications/ibm-mas-account-root/templates/000-cluster-appset.yaml)**. This generates a set of **MAS Cluster Root Applications** based on the configuration in the **Config Git Repo*. 

The **Cluster Root Application** [Helm Chart](root-applications/ibm-mas-cluster-root) contains templates that generate ArgoCD Applications for configuring various dependencies shared by MAS instances on the target cluster, including:

- [Operator Catalog](root-applications/ibm-mas-cluster-root/templates/000-ibm-operator-catalog-app.yaml) ([Helm Chart](cluster-applications/))
- [Redhat Certificate Manager](root-applications/ibm-mas-cluster-root/templates/010-ibm-redhat-cert-manager-app.yaml) ([Helm Chart](cluster-applications/010-redhat-cert-manager))
- [DRO](root-applications/ibm-mas-cluster-root/templates/010-ibm-dro-app.yaml) ([Helm Chart](cluster-applications/020-ibm-dro))
- [Db2u Operator](root-applications/ibm-mas-cluster-root/templates/020-ibm-db2u-app.yaml) ([Helm Chart](cluster-applications/060-ibm-db2u))
- [CIS Compliance](root-applications/ibm-mas-cluster-root/templates/040-cis-compliance-app.yaml) ([Helm Chart](cluster-applications/040-cis-compliance))
- [Nvidia GPU Operator](root-applications/ibm-mas-cluster-root/templates/050-nvidia-gpu-operator-app) ([Helm Chart](cluster-applications/050-nvidia-gpu-operator))


The **Cluster Root Application** [Helm Chart](root-applications/ibm-mas-cluster-root) also installs the **[MAS Instance Root Application Set](root-applications/ibm-mas-cluster-root/templates/099-instance-appset.yaml)**. This generates a set of **MAS Instance Root Applications** based on the configuration in the **Config Git Repo**.  

The **MAS Instance Root Application** [Helm Chart](root-applications/ibm-mas-instance-root) contains templates for generating ArgoCD Applications that install and configure some instance-level dependencies (e.g. SLS, DB2 Databases), MAS Core and various (MAS) applications (e.g. Manage, Monitor, etc) in the appropriate namespace on the target cluster:
 
- [CP4D](root-applications/ibm-mas-instance-root/templates/080-ibm-cp4d-app.yaml) ([Helm Chart](instance-applications/080-ibm-cp4d))
- [SLS (Suite License Service)](root-applications/ibm-mas-instance-root/templates/100-ibm-sls-app.yaml) ([Helm Chart](instance-applications/100-ibm-sls))
- [MAS Suite](root-applications/ibm-mas-instance-root/templates/130-ibm-mas-suite-app.yaml) ([Helm Chart](instance-applications/130-ibm-mas-suite))
- [MAS App Assist Install](root-applications/ibm-mas-instance-root/templates/500-ibm-mas-masapp-assist-install.yaml) ([Helm Chart](instance-applications/500-540-ibm-mas-suite-app-install))
- [MAS App IoT Install](root-applications/ibm-mas-instance-root/templates/500-ibm-mas-masapp-iot-install.yaml) ([Helm Chart](instance-applications/500-540-ibm-mas-suite-app-install))
- [MAS App Manage Install](root-applications/ibm-mas-instance-root/templates/500-ibm-mas-masapp-manage-install.yaml) ([Helm Chart](instance-applications/500-540-ibm-mas-suite-app-install))
- [MAS App VisualInspection Install](root-applications/ibm-mas-instance-root/templates/500-ibm-mas-masapp-visualinspection-install.yaml) ([Helm Chart](instance-applications/500-540-ibm-mas-suite-app-install))
- [MAS App Health Install](root-applications/ibm-mas-instance-root/templates/520-ibm-mas-masapp-health-install.yaml) ([Helm Chart](instance-applications/500-540-ibm-mas-suite-app-install))
- [MAS App Monitor Install](root-applications/ibm-mas-instance-root/templates/520-ibm-mas-masapp-monitor-install.yaml) ([Helm Chart](instance-applications/500-540-ibm-mas-suite-app-install))
- [MAS App Optimizer Install](root-applications/ibm-mas-instance-root/templates/520-ibm-mas-masapp-optimizer-install.yaml) ([Helm Chart](instance-applications/500-540-ibm-mas-suite-app-install))
- [MAS App Predict Install](root-applications/ibm-mas-instance-root/templates/540-ibm-mas-masapp-predict-install.yaml) ([Helm Chart](instance-applications/500-540-ibm-mas-suite-app-install))


There are some special templates in the **MAS Instance Root Application** [Helm Chart](root-applications/ibm-mas-instance-root) that are capable of generating multiple Applications; necessary when there may be one or more instances of that type of resource, which will vary between MAS instances - for instance DB2 databases, suite configs, and suite/application workspaces:

- [DB2 Databases](root-applications/ibm-mas-instance-root/templates/120-db2-databases-app.yaml) ([Helm Chart](instance-applications/120-ibm-db2u-database))
- [MAS Workspaces](root-applications/ibm-mas-instance-root/templates/200-ibm-mas-workspaces.yaml) ([Helm Chart](instance-applications/220-ibm-mas-workspace))
- [MAS App Configs](root-applications/ibm-mas-instance-root/templates/510-550-ibm-mas-masapp-configs) ([Helm Chart](instance-applications/510-550-ibm-mas-suite-app-config))
- [Suite Configs](root-applications/ibm-mas-instance-root/templates/130-ibm-mas-suite-configs-app.yaml)
  - This application is responsible for installing various types of suite configuration types (Mongo, BAS, SMTP, etc) at various scopes (system, app, ws, wsapp). The Helm Chart it uses is chosen dynanmically based on the configuration type:
    - [JDBC Config](instance-applications/130-ibm-jdbc-config)
    - [Kafka Config](instance-applications/130-ibm-kafka-config)
    - [BAS Config](instance-applications/130-ibm-mas-bas-config)
    - [IDP Config](instance-applications/130-ibm-mas-idp-config)
    - [Mongo Config](instance-applications/130-ibm-mas-mongo-config)
    - [SLS Config](instance-applications/130-ibm-mas-sls-config)
    - [SMTP Config](instance-applications/130-ibm-mas-smtp-config)
    - [COS Config](instance-applications/130-ibm-objectstorage-config)

