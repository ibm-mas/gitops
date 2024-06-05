# gitops

A GitOps approach to managing Maximo Application Suite.

## Table of Contents
> TODO: make these links
- Architecture
- Application Structure
- Config Git Repository Structure
- Application and ApplicationSet Details
- Deployment Orchestration

## Architecture

![Architecture](docs/png/architecture.png)

The **Source Git Repo** provides Helm Charts that define all of the Kubernetes resources required to deploy MAS instances using ArgoCD. The [ibm-mas/gitops](https://github.com/ibm-mas/gitops/tree/demo2) repository can be used directly as the **Source Git Repo**, or a fork can be used if desired.

The **Config Git Repo** provides configuration YAML files that define the Values for rendering the Helm Charts in the **Source Git Repo**. The  **Config Git Repo** defines how many MAS instances will be deployed and where and how each of the MAS instances are configured. Each top-level folder contains the config for one **Account** (e.g. "dev", "staging", "production"). Each **Account**  has a subfolder per **Target Cluster**. And each **Target Cluster** has a subfolder per **MAS Instance** that should run on that cluster.

The **Secrets Vault** is used to store sensitive values that should not be exposed in the **Source Git Repo**. They are fetched at runtime using the [ArgoCD Vault Plugin](https://argocd-vault-plugin.readthedocs.io/en/stable/) from some backend implementation (e.g. AWS Secrets Manager). 

ArgoCD is installed and configured on some **Management Cluster**. A single **Account Root Application** is registered with ArgoCD. This tells ArgoCD how to access the **Source Git Repo**, **Config Git Repo** and **Secrets Vault** and which **Account ID** (i.e. which top-level folder of the **Config Git Repo**)  to monitor for configuration files. 

The **Account Root Application** is the only Application that is created directly. We employ the [App of Apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern) whereby the **Account Root Application** uses the artifacts in the **Source Git Repo**, **Config Git Repo** and **Secrets Vault** to dynamically generate (a tree of) further Applications (and ApplicationSets) which themselves may generate other Applications (and ApplicationSets) and/or configure a set of resources on one of the **Target Clusters**.



## Application Structure


The following figure shows the generated tree of ArgoCD applications and ApplicationSets, starting with the **Account Root Application** at the top:

![Application Structure](docs/png/appstructure.png)


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
    - [JDBC Config](instance-applications/130-ibm-db2u-jdbc-config)
    - [Kafka Config](instance-applications/130-ibm-kafka-config)
    - [BAS Config](instance-applications/130-ibm-mas-bas-config)
    - [IDP Config](instance-applications/130-ibm-mas-idp-config)
    - [Mongo Config](instance-applications/130-ibm-mas-mongo-config)
    - [SLS Config](instance-applications/130-ibm-mas-sls-config)
    - [SMTP Config](instance-applications/130-ibm-mas-smtp-config)
    - [COS Config](instance-applications/130-ibm-objectstorage-config)

### Config Git Repository Structure

The **Config Git Repo** represents the "source of truth" that (along with the Charts in the **Source Git Repo** and the secrets in the **Secrets Vault**) provides everything ArgoCD needs to install and manage MAS instances across the target clusters. 

The **Config Git Repo** is structured as a hierarchy, with "accounts" (e.g. dev/prod/staging) at the top, followed by "clusters", followed by "instances". Each level contains different types of `.yaml` configuration files. Each `.yaml` file will cause ArgoCD to generate one (or more) application(s), which in turn render Helm charts into the appropriate target cluster.

```
├── <ACCOUNT_ID>
│   └── <CLUSTER_ID>
│       ├── <INSTANCE_ID>
│       │   ├── ibm-db2u-databases.yaml
│       │   ├── ibm-mas-instance-base.yaml
│       │   ├── ibm-mas-masapp-assist-install.yaml
│       │   ├── ibm-mas-masapp-configs.yaml
│       │   ├── ibm-mas-masapp-iot-install.yaml
│       │   ├── ibm-mas-masapp-manage-install.yaml
│       │   ├── ibm-mas-masapp-monitor-install.yaml
│       │   ├── ibm-mas-masapp-optimizer-install.yaml
│       │   ├── ibm-mas-masapp-visualinspection-install.yaml
│       │   ├── ibm-mas-suite-configs.yaml
│       │   ├── ibm-mas-suite.yaml
│       │   ├── ibm-mas-workspaces.yaml
│       │   └── ibm-sls.yaml
│       ├── ibm-db2u.yaml
│       ├── ibm-dro.yaml
│       ├── ibm-mas-cluster-base.yaml
│       ├── ibm-operator-catalog.yaml
│       ├── nvidia-gpu-operator.yaml
│       └── redhat-cert-manager.yaml
```

> See the `example-config` directory in this repository for some actual examples of each of these `.yaml` files.

Here is the structure of an example **Config Git Repo** containing configuration for three accounts (`dev`, `staging`, `production`) with a number of clusters and MAS instances. For brevity, the actual `.yaml` file names are not shown here.
```
├── dev
│   ├── cluster1
│   │   ├── instance1
│   │   │   └── *.yaml
│   │   ├── instance2
│   │   │   └── *.yaml
│   │   ├── instance3
│   │   │   └── *.yaml
│   │   └── *.yaml
│   └── cluster2
│       ├── *.yaml
│       └── instance1
│           └── *.yaml
├── staging
│   └── cluster1
│       ├── instance1
│       │   └── *.yaml
│       ├── instance2
│       │   └── *.yaml
│       └── *.yaml
└── production
    └── cluster1
        ├── *.yaml
        ├── instance1
        │   └── *.yaml
        └── instance2
            └── *.yaml
```

### The Applications and Application Sets in Detail

Let's take a more detailed look at the Applications and Application Sets and how they all hang together.

#### The Cluster Root Application Set

The **Cluster Root Application Set** employs a list of ArgoCD [Git File Generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/#git-generator-files) to monitor for named YAML configuration files at the cluster level in the **Config Git Repo**. All cluster-level YAML configuration files contain a `merge-key`. The `merge-key` includes the Account and Cluster ID (e.g. `dev/cluster1`). The ArgoCD [Merge Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Merge/) groups the individual YAML files according to their `merge-key`, resulting in a combined YAML object for each target cluster that we want to manage MAS instances on. The `ibm-mas-cluster-base.yaml` file contains global configuration for the target cluster, and the other YAML configuration files represent once type of cluster-level application that we wish to install on the target cluster (e.g. `ibm-operator-catalog.yaml`, `ibm-dro.yaml`, `ibm-db2u.yaml`, and so on). For the sake of brevity we will only cover one of these (`ibm-operator-catalog.yaml`) here:
```yaml
spec:
  ...
  generators:
    - merge:
        mergeKeys:
          - 'merge-key'
        generators:
          - git:
              files:
              - path: "{{ .Values.account.id }}/*/ibm-mas-cluster-base.yaml"
          - git:
              files:
              - path: "{{ .Values.account.id }}/*/ibm-operator-catalog.yaml"
          ...
```

For example, if our **Git Config Repo** contains the following:
> 
> ```
> ├── dev
> │   ├── cluster1
> │   │   ├── ibm-mas-cluster-base.yaml
> │   │   ├── ibm-operator-catalog.yaml
> │   └── cluster2
> │   │   ├── ibm-mas-cluster-base.yaml
> │   │   ├── ibm-operator-catalog.yaml
> ```
> dev/cluster1/ibm-mas-cluster-base.yaml:
> ```yaml
> merge-key: "dev/cluster1"
> account:
>   id: dev
> cluster:
>   id: cluster1
>   url: https://api.cluster1.cakv.p3.openshiftapps.com:443
> ```
> dev/cluster1/ibm-operator-catalog.yaml:
> ```yaml
> merge-key: "dev/cluster1"
> ibm_operator_catalog:
>   mas_catalog_version: v8-240430-amd64
> ```
>
> dev/cluster2/ibm-mas-cluster-base.yaml:
> ```yaml
> merge-key: "dev/cluster2"
> account:
>   id: dev
> cluster:
>   id: cluster2
>   url: https://api.cluster2.jsig.p3.openshiftapps.com:443
> ```
> dev/cluster2/ibm-operator-catalog.yaml:
> ```yaml
> merge-key: "dev/cluster2"
> ibm_operator_catalog:
>    mas_catalog_version: v8-240405-amd64
>  ```

The **Cluster Root Application Set**  generators would produce two YAML objects:
> ```yaml
>  merge-key: "dev/cluster1"
>  account:
>    id: dev
>  cluster:
>    id: cluster1
>    url: https://api.cluster1.cakv.p3.openshiftapps.com:443
>  ibm_operator_catalog:
>    mas_catalog_version: v8-240430-amd64
> ```

> ```yaml
>  merge-key: "dev/cluster2"
>  account:
>    id: dev
>  cluster:
>    id: cluster2
>    url: https://api.cluster2.jsig.p3.openshiftapps.com:443
>  ibm_operator_catalog:
>    mas_catalog_version: v8-240405-amd64
> ```

Each YAML object is used to render the **Cluster Root Application Set** template to generate a new **Cluster Root Application**:
```yaml
  template:
    metadata:
      name: "cluster.{{ `{{.cluster.id}}` }}"
      ...
    spec:
      source:
        path: root-applications/ibm-mas-cluster-root
        helm:
          values: "{{ `{{ toYaml . }}` }}"
```
[Go Template](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/GoTemplate/) expressions are used to inject values from the cluster's YAML object into the template. E.g. `.cluster.id` is either `cluster1` or `cluster2` and `{{ toYaml . }}` renders the cluster's YAML object in its entirety.

> **What are the backticks for?** Since the **Cluster Root Application Set** is itself a Helm template (rendered by the **Account Root Application**), we need to tell Helm to not attempt to parse the Go Template expressions and treat them as literals instead. This achieved by wrapping the go template expressions in backticks. When the above is rendered by Helm, it will look like this:
> ```yaml
>  template:
>    metadata:
>      name: "cluster.{{.cluster.id}}"
>      ...
>    spec:
>      source:
>        path: root-applications/ibm-mas-cluster-root
>        helm:
>          values: "{{ toYaml . }}"
> ```
>

Additional global configuration parameters (such as details for the **Source Git Repo** and the namespace where ArgoCD is running) sourced from the **Account Root Application** are also passed down the Application tree as additional Helm parameters:
```yaml
            parameters:
              - name: "source.repo_url"
                value: "{{ .Values.source.repo_url }}"
              - name: "argo.namespace"
                value: "{{ .Values.argo.namespace }}"
```

The **Cluster Root Application** Helm Chart defines further ArgoCD Applications and so should be rendered into the cluster and namespace where ArgoCD is running. We specify the following:
```yaml
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: {{ .Values.argo.namespace }}
```

To complete our example above, two **Cluster Root Applications** would be generated:
> cluster1:
> ```yaml
> kind: Application
> metadata:
>   name: cluster.cluster1
> spec:
>   source:
>     path: root-applications/ibm-mas-cluster-root
>     helm:
>       values: |-
>         merge-key: dev/cluster1`
>         account:
>           id: dev
>         cluster:
>           id: cluster1
>           url: https://api.cluster1.cakv.p3.openshiftapps.com:443
>         ibm_operator_catalog:
>           mas_catalog_version: v8-240430-amd64
>       parameters:
>         - name: source.repo_url
>           value: "https://github.com/..."
>         - name: argo.namespace
>           value: "openshift-gitops"
>   destination:
>     server: 'https://kubernetes.default.svc'
>     namespace: openshift-gitops
> ```
> cluster2:
> ```yaml
> kind: Application
> metadata:
>   name: cluster.cluster2
> spec:
>   source:
>     path: root-applications/ibm-mas-cluster-root
>     helm:
>       values: |-
>         merge-key: dev/cluster2`
>         account:
>           id: dev
>         cluster:
>           id: cluster2
>           url: https://api.cluster2.jsig.p3.openshiftapps.com:443
>         ibm_operator_catalog:
>           mas_catalog_version: v8-240405-amd64
>       parameters:
>         - name: source.repo_url
>         - value: "https://github.com/..."
>         - name: argo.namespace
>           value: "openshift-gitops"
>   destination:
>     server: 'https://kubernetes.default.svc'
>     namespace: openshift-gitops
> ```



#### The Cluster Root Application

The **Cluster Root Application** Helm Chart contains templates to conditionally render ArgoCD Applications once the configuration for the ArgoCD Application is present. Application-specific configuration is held under a unique top-level field, e.g. `ibm_operator_catalog`, `ibm_db2u` and so on. 

If we look at the [000-ibm-operator-catalog-app template](root-applications/ibm-mas-cluster-root/templates/000-ibm-operator-catalog-app.yaml) for example, we can see it is guarded by:
```yaml
{{- if not (empty .Values.ibm_operator_catalog) }}
```
Following on from the example above, once `dev/cluster1/ibm-operator-catalog.yaml` is pushed to the **Git Config Repo**, the `ibm_operator_catalog` key will appear in the Helm values for `cluster1`'s **Cluster Root Application**. This will result in an ArgoCD Application that will render the [ibm-operator-catalog Helm Chart](cluster-applications/000-ibm-operator-catalog) into the target cluster.

Looking again at [000-ibm-operator-catalog-app template](root-applications/ibm-mas-cluster-root/templates/000-ibm-operator-catalog-app.yaml), we can see it will generate an ArgoCD application named `operator-catalog.{{ .Values.cluster.id}}` (e.g. `operator-catalog.cluster1`, `operator-catalog.cluster2`). It will render the [ibm-operator-catalog Helm Chart](cluster-applications/000-ibm-operator-catalog) into the targer cluster identified by the `.Values.cluster.url` value from the global cluster configuration in `ibm-mas-cluster-base.yaml`. In thie case, we know some of the values will be [inline-path placeholders](https://argocd-vault-plugin.readthedocs.io/en/stable/howitworks/#inline-path-placeholders) for referencing secrets in the **Secrets Vault**, so we use the AVP plugin source to render the Helm chart.
```yaml
kind: Application
metadata:
  name: operator-catalog.{{ .Values.cluster.id }}
spec:
  destination:
    server: {{ .Values.cluster.url }}
  source:
    path: cluster-applications/000-ibm-operator-catalog
    plugin:
      name: argocd-vault-plugin-helm
      env:
        - name: HELM_VALUES
          value: |
            mas_catalog_version: "{{ .Values.ibm_operator_catalog.mas_catalog_version  }}"
```

As per our example, two **Cluster Root Application**s will be generated:
> cluster1:
> ```yaml
> kind: Application
> metadata:
>   name: operator-catalog.cluster1
> spec:
>   destination:
>     server: https://api.cluster1.cakv.p3.openshiftapps.com:443
>   source:
>     path: cluster-applications/000-ibm-operator-catalog
>     plugin:
>       name: argocd-vault-plugin-helm
>       env:
>         - name: HELM_VALUES
>           value: |
>             mas_catalog_version: "v8-240430-amd64"
> ```
> cluster2:
> ```yaml
> kind: Application
> metadata:
>   name: operator-catalog.cluster2
> spec:
>   destination:
>     server: https://api.cluster2.jsig.p3.openshiftapps.com:443
>   source:
>     path: cluster-applications/000-ibm-operator-catalog
>     plugin:
>       name: argocd-vault-plugin-helm
>       env:
>         - name: HELM_VALUES
>           value: |
>             mas_catalog_version: "v8-240405-amd64"
> ```


The other Application templates (e.g. [010-ibm-redhat-cert-manager-app.yaml](root-applications/ibm-mas-cluster-root/templates/010-ibm-redhat-cert-manager-app.yaml), [020-ibm-dro-app.yaml](root-applications/ibm-mas-cluster-root/templates/020-ibm-dro-app.yaml) and so on) all follow this pattern and work in a similar way.

The **Cluster Root Application** chart also includes the [099-instance-appset.yaml](root-applications/ibm-mas-cluster-root/templates/099-instance-appset.yaml) which generates a new **Instance Root Application Set** for each cluster.

#### The Instance Root Application Set

The [Instance Root Application Set](root-applications/ibm-mas-cluster-root/templates/099-instance-appset.yaml) is responsible for generating an **Instance Root Application** per MAS instance on the target cluster. It follows the same pattern as the Cluster Root Application Set described [above](#the-cluster-root-application-set). The key differences are:
- `merge-keys` in the instance-level configuation YAML files also contain a MAS instance ID, e.g. `dev/cluster1/instance1`.
- The Git File generators look for a different set of named YAML files at the **instance** level in the **Config Git Repo**:
  ```yaml
  spec:
    ...
    generators:
      - merge:
          mergeKeys:
            - 'merge-key'
          generators:
            - git:
                files:
                - path: "{{ .Values.account.id }}/{{ .Values.cluster.id }}/*/ibm-mas-instance-base.yaml"
            - git:
                files:
                - path: "{{ .Values.account.id }}/{{ .Values.cluster.id }}/*/ibm-mas-suite.yaml"
  ```
- The generated **Instance Root Applications** source the [ibm-mas-instance-root Helm Chart](root-applications/ibm-mas-instance-root).

To continue our example above, our **Git Config Repo** now contains some additional instance-level config files (only showing `cluster1` now for brevity):
> 
> ```
> ├── dev
> │   ├── cluster1
> │   │   ├── ibm-mas-cluster-base.yaml
> │   │   ├── ibm-operator-catalog.yaml
> │       ├── instance1
> │       │   ├── ibm-mas-instance-base.yaml
> │       │   ├── ibm-mas-suite.yaml
> ...
> ```
> dev/cluster1/instance1/ibm-mas-instance-base.yaml:
> ```yaml
> merge-key: "dev/cluster1/instance1"
> account:
>   id: dev
> cluster:
>   id: cluster1
>   url: https://api.cluster1.cakv.p3.openshiftapps.com:443
> instance:
>   id: instance1
> ```
> dev/cluster1/instance1/ibm-mas-suite.yaml:
> ```yaml
> merge-key: "dev/cluster1/instance1"
> ibm_mas_suite:
>   mas_channel: "8.11.x"
> ```
>

The **Instance Root Application Set** generators would produce a YAML object:
> ```yaml
> merge-key: "dev/cluster1/instance1"
> account:
>   id: dev
> cluster:
>   id: cluster1
>   url: https://api.cluster1.cakv.p3.openshiftapps.com:443
> instance:
>   id: instance1
> ibm_mas_suite:
>   mas_channel: "8.11.x"
> ```

This would be used to render the **Instance Root Application Set** template and generate an **Instance Root Application**:
> ```yaml
> kind: Application
> metadata:
>   name: instance.cluster1.instance1
> spec:
>   source:
>     path: root-applications/ibm-mas-instance-root
>     helm:
>       values: |-
>         merge-key: dev/cluster1/instance1
>         account:
>           id: dev
>         cluster:
>           id: cluster1
>           url: https://api.cluster1.cakv.p3.openshiftapps.com:443
>         instance:
>           id: instance1
>         ibm_mas_suite:
>           mas_channel: "8.11.x"
>       parameters:
>         - name: source.repo_url
>           value: "https://github.com/..."
>         - name: argo.namespace
>           value: "openshift-gitops"
>   destination:
>     server: 'https://kubernetes.default.svc'
>     namespace: openshift-gitops
> ```

The **Instance Root Application** Helm chart will generate further Applications in the ArgoCD cluster and namespace.

#### The Instance Root Application

The **Instance Root Application** Helm chart contains templates to conditionally render ArgoCD Applications once the configuration for the ArgoCD Application is present. It follows the same pattern as the **Cluster Root Application** described [above](#the-cluster-root-application); specific applications are enabled once their configuration becomes present. For instance, the [130-ibm-mas-suite-app.yaml](root-applications/ibm-mas-instance-root/templates/130-ibm-mas-suite-app.yaml) template generates an Application that deploys the MAS `Suite` CR to the target cluster once configuration under the `ibm_mas_suite` key is present.

Some special templates are capable of generating multiple applications: [120-db2-databases-app.yaml](root-applications/ibm-mas-instance-root/templates/120-db2-databases-app.yaml), [130-ibm-mas-suite-configs-app.yaml)](root-applications/ibm-mas-instance-root/templates/130-ibm-mas-suite-configs-app.yaml), [200-ibm-mas-workspaces.yaml](root-applications/ibm-mas-instance-root/templates/200-ibm-mas-workspaces.yaml) and [130-ibm-mas-suite-configs-app.yaml](root-applications/ibm-mas-instance-root/templates/130-ibm-mas-suite-configs-app.yaml). These are special cases where there can be more than one instance of the *type* of resource that these Applications are responsible for managing. For instance, the MAS instance may require more than one DB2 Database. In these cases, we make use of the Helm `range` control structure to iterate over a YAML list held in the configuration, e.g. [120-db2-databases-app.yaml](root-applications/ibm-mas-instance-root/templates/120-db2-databases-app.yaml):
```yaml
{{- range $i, $value := .Values.ibm_db2u_databases }}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: "db2-db.{{ $.Values.cluster.id }}.{{ $.Values.instance.id }}.{{ $value.mas_application_id }}"
...
{{- end}}
```

Iterates over the list held in the `ibm-db2u-databases.yaml` configuration file for the instance to generate any number of DB2 Database Applications each configured as needed.
```yaml
ibm_db2u_databases:
  - mas_application_id: iot
    db2_memory_limits: 12Gi
    ...
  - mas_application_id: manage
    db2_memory_limits: 16Gi
    db2_database_db_config:
      CHNGPGS_THRESH: '40'
      ...
    ...
```


> **Why not use ApplicationSets here?** We encountered some limitations when using ApplicationSets for this purpose. For instance, Applications generated by ApplicationSets do not participate in the [ArgoCD syncwave](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) with other Applications so we would have no way of ensuring that resources would be configured in the correct order. By using the Helm `range` control structure we generate "normal" Applications that do not suffer from this limitation. This means, for instance, that we can ensure that DB2 Databases are configured **before** attempting to provide the corresponding JDBC configuration to MAS.


### Deployment Orchestration

To ensure that we sync resources in the correct order they are annotated with an ArgoCD [sync wave](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/). For clarity, we also prefix all resource filenames with the sync wave that they belong to. Note that sync waves are *local* to each ArgoCD application (i.e. each Helm chart).

> TODO: document the various use of ArgoCD hooks for creating secrets / running scripts / etc.

> TODO: we often don't use post-sync hooks - instead we use normal jobs that run last. These jobs often perform pre-requisite steps for subsequent sync waves (e.g. setting up secrets in the **Secrets Vault**) and having them as "normal" jobs ensures that ArgoCD will wait for their completion before allowing Applications in subsequent syncwaves to proceed.

> TODO: Document custom health checks, in particular the Application healthcheck required for the App of Apps pattern to work:  https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#argocd-app




### Reference

#### Account Root Application Manifest

> Replace the following:
>   - `<source-repo-url>`: The url of the source helm charts and argo apps. e.g. https://github.com/ibm-mas/gitops.
>   - `<source-repo-revision>`: The branch of `<source-repo-url>` to source charts from, e.g. `master`.
>   - `<config-repo>`: The github repo to source cluster/instance configuration from, e.g. `git@github.ibm.com:maximoappsuite/gitops-envs.git`.
>   - `<config-repo-revision>`: The revision of `<config-repo>` to source cluster/instance configuration from, e.g. `master`.
>   - `<account-id>`: The ID of the account this root application manages. This also determines the root folder in `<config-repo>`:`<config-repo-revision` to source cluster/instance configuration from, e.g. `aws-dev`.
>   - `<argo-namespace>`: The namespace on cluster running ArgoCD. E.g. `openshift-gitops` (internal clusters), `argocd-worker` (MCSP). This determines where Application and ApplicationSet resources will be created. It will also be used to annotate namespaces created by our charts with [argocd.argoproj.io/managed-by](https://argocd-operator.readthedocs.io/en/stable/usage/deploy-to-different-namespaces/).
>   - `<argo-project-rootapps>`: The ArgoCD project in which to create root applications (including this Application and the root applications that it generates). The project must be configured to permit creation of `argoproj.io.Application` and `argoproj.io.ApplicationSet` resources in the `<argoapp-namespace>` of the cluster in which ArgoCD is running (i.e. `https://kubernetes.default.svc`). In fvtsaas, this project is currently `mas`. In the MCSP dev worker, it is `mas-argoproj-resources`.
>   - `<argo-project-apps>`: The ArgoCD project in which to create the applications that deploy MAS resources (and their dependencies) to external MAS clusters. The project must be configured to permit creation of any resource in any namespace of all external MAS clusters targeted by this account. In fvtsaas, this project is currently `mas`. In the MCSP dev worker, it is also `mas`.
>   - `<avp-name>`: The name assigned to the ArgoCD Vault Plugin used for retrieving secrets. Defaults to `argocd-vault-plugin-helm`. In MCSP, this must be `argocd-vault-plugin-helm-inline`.
>   - `<avp-secret>`: The name of the k8s secret containing the credentials for accessing the vault that AVP is linked with. Defaults to the empty string, which implies that these credentials have been configured already in the cluster.
>   - `<avp-values_varname>`: The name of the environment variable used to pass values inline to AVP. Defaults to `HELM_VALUES`. In MCSP this must be `HELM_INVLINE_VALUES`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root.<account-id>
  namespace: <argoapp-namespace>
spec:
  destination:
    namespace: <argoapp-namespace>
    server: 'https://kubernetes.default.svc'
  project: "<argo-project-rootapps>"
  source:
    path: root-applications/ibm-mas-account-root
    repoURL: <source-repo-url>
    targetRevision: "<source-repo-revision>"
    helm:
      values: |
          account:
            id: "<account-id>

          generator:
            repo_url: "<config-repo>"
            revision: "<config-repo-revision>"

          source:
            repo_url: "<source-repo-url>"
            revision: "<source-repo-revision>"
          
          argo:
            namespace: "<argo-namespace>"
            projects:
              rootapps: "<argo-project-rootapps>
              apps: "<argo-project-apps>"

          avp:
            name: "<avp-name>"
            secret: "<avp-secret>"
            values_varname: "<val-values-varname>"
    
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
```

#### Secrets


### Known Limitations

#### A single ArgoCD instance cannot manage more than one Account Root Application
This is primarily due to a limitation we have inherited to be compatible with internal IBM systems where we must have everything under a single ArgoCD project. This limitation could be addressed by adding support for multi-project configurations, assigning each **Account Root Application** its own project in ArgoCD. This is something we'd like to do in the long term but it's not a priority at the moment.


#### AWS Secrets Manager only (for now)