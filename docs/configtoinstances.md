Mapping Config to MAS Deployments
===============================================================================

A combination of [ArgoCD Application Sets](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/) and the [App of Apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern) is used by MAS GitOps to generate a tree of ArgoCD Applications that install and manage MAS instances in {{ target_clusters() }} based on the configuration files in the {{ config_repo() }}.

The tree of Applications and Application Sets looks like this:

![Application Structure](drawio/appstructure.drawio)

The following describes *how* this tree is generated.

The Account Root Application
-------------------------------------------------------------------------------

It begins with the **Account Root Application**. This is created directly on the cluster running ArgoCD. It serves as the "entrypoint" to the MAS Gitops Helm Charts and is where several key pieces of global configuration values are provided.

The manifest for the **Account Root Application** in our example is shown in the snippet below. The account ID, source repo, config (aka "generator") repo are configured here.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root.dev
  namespace: openshift-gitops
spec:
  destination:
    namespace: openshift-gitops
    server: 'https://kubernetes.default.svc'
  project: "mas"
  source:
    path: root-applications/ibm-mas-account-root
    repoURL: https://github.com/ibm-mas/gitops
    targetRevision: master
    helm:
      values: |
        account:
          id: dev

        source:
          repo_url: "https://github.com/ibm-mas/gitops"
          revision: "mas"

        generator:
          repo_url: "https://github.com/me/my-config-repo"
          revision: "main"

        argo:
          namespace: "openshift-gitops"
```

The  **Account Root Application** establishes the {{ cluster_root_app_set() }}.



The Cluster Root Application Set
-------------------------------------------------------------------------------
The {{ cluster_root_app_set() }} generates a set of **Cluster Root Applications** based on the configuration in the {{ config_repo() }}.

The {{ cluster_root_app_set() }} employs an ArgoCD [Merge Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Merge/) with a list of ArgoCD [Git File Generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/#git-generator-files). The Git File Generators monitor for named YAML configuration files at the cluster level in the {{ config_repo() }} and the Merge Generator combines each of these files into a single YAML object per MAS cluster. 

A simplified and abridged snippet showing the Merge and Git File generators from the {{ cluster_root_app_set() }} template is shown below:


```yaml
{% raw %}spec:
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
          ...{% endraw %}
```

To illustrate, the following shows an example {{ config_repo() }} that defines  a `dev` account containing configuration for two {{ target_clusters() }} (`cluster1` and `cluster2`). These are the files that the Git File Generators above are looking for.
```none
├── dev
│   ├── cluster1
│   │   ├── ibm-mas-cluster-base.yaml
│   │   ├── ibm-operator-catalog.yaml
│   └── cluster2
│   │   ├── ibm-mas-cluster-base.yaml
│   │   ├── ibm-operator-catalog.yaml
```


Now let's take a look at the contents of these files:

```
├── dev
│   ├── cluster1
|   |   |-------------------------------------------
│   │   ├── ibm-mas-cluster-base.yaml
|   |   |-------------------------------------------
|   |   |   merge-key: "dev/cluster1"
|   |   |   account:
|   |   |     id: dev
|   |   |   cluster:
|   |   |     id: cluster1
|   |   |     url: https://api.cluster1.cakv.p3.openshiftapps.com:443
|   |   |
|   |   |-------------------------------------------
│   │   ├── ibm-operator-catalog.yaml
|   |   |-------------------------------------------
|   |   |   merge-key: "dev/cluster1"
|   |   |   ibm_operator_catalog:
|   |   |      mas_catalog_version: v8-240430-amd64
|   |   |
│   └── cluster2
|   |   |-------------------------------------------
│   │   ├── ibm-mas-cluster-base.yaml
|   |   |-------------------------------------------
|   |   |   merge-key: "dev/cluster2"
|   |   |   account:
|   |   |      id: dev
|   |   |   cluster:
|   |   |     id: cluster2
|   |   |     url: https://api.cluster2.jsig.p3.openshiftapps.com:443
|   |   |
|   |   |-------------------------------------------
│   │   ├── ibm-operator-catalog.yaml
|   |   |-------------------------------------------
|   |   |   merge-key: "dev/cluster2"
|   |   |   ibm_operator_catalog:
|   |   |   mas_catalog_version: v8-240405-amd64
```

All of the files contain a `merge-key` which includes the account ID and the cluster ID (e.g. `dev/cluster1`). This is used by the Merge generator to group together configuration into per-cluster YAML objects.

The `ibm-mas-cluster-base.yaml` file contains global configuration for the cluster, including the `account.id`, and the `cluster.id` and the `cluster.url` which determines the {{ target_cluster() }} that ArgoCD will deploy resources to.

The other YAML configuration files (such as `ibm-operator-catalog.yaml` shown above) represent one type of cluster-level resource that we wish to install on the {{ target_cluster() }}.


Given the config above, {{ cluster_root_app_set() }} generates two YAML objects:
```yaml
 merge-key: "dev/cluster1"
 account:
   id: dev
 cluster:
   id: cluster1
   url: https://api.cluster1.cakv.p3.openshiftapps.com:443
 ibm_operator_catalog:
   mas_catalog_version: v8-240430-amd64
```

```yaml
 merge-key: "dev/cluster2"
 account:
   id: dev
 cluster:
   id: cluster2
   url: https://api.cluster2.jsig.p3.openshiftapps.com:443
 ibm_operator_catalog:
   mas_catalog_version: v8-240405-amd64
```

The generated YAML objects are used to render the template defined in the {{ cluster_root_app_set() }} to generate **Cluster Root Applications** in the {{ management_cluster() }}.

- [Go Template](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/GoTemplate/) expressions are used to inject **cluster-specific** configuration from the cluster's YAML object into the template (e.g. `{% raw %}{{.cluster.id}}{% endraw %}`).

- Global configuration that applies to all clusters is passed down from the Helm values used to render the {{ cluster_root_app_set() }} template (e.g. `{% raw %}{{ .Values.source.repo_url }}{% endraw %}`).

A simplified and abridged snippet of the {{ cluster_root_app_set() }} template is shown below, followed by a breakdown of the purpose of each section:

```yaml
  {% raw %}template:
    metadata:
      name: "cluster.{{ `{{.cluster.id}}` }}"
      ...
    spec:
      source:
        path: root-applications/ibm-mas-cluster-root
        helm:
          values: "{{ `{{ toYaml . }}` }}"

        parameters:
          - name: "source.repo_url"
            value: "{{ .Values.source.repo_url }}"
          - name: "argo.namespace"
            value: "{{ .Values.argo.namespace }}"

      destination:
        server: 'https://kubernetes.default.svc'
        namespace: {{ .Values.argo.namespace }}{% endraw %}
```

!!! info  "What are the backticks for?"

    Since the **Cluster Root Application Set** is itself a Helm template (rendered by the **Account Root Application**) we need to tell Helm to not attempt to parse the Go Template expressions, treating them as literals instead. This is achieved by wrapping the Go Template expressions in backticks. The expressions in the snippet above will be rendered by Helm as `{% raw %}"cluster.{{.cluster.id}}"{% endraw %}` and `{% raw %}"{{ toYaml . }}"{% endraw %}`.


The **Cluster Root Applications** are named according to their ID:
```yaml
template:
  metadata:
    {% raw %}name: "cluster.{{ `{{.cluster.id}}` }}"{% endraw %}
```

**Cluster Root Applications** render the {{ cluster_root_chart() }}:
```yaml
      {% raw %}source:
        path: root-applications/ibm-mas-cluster-root{% endraw %}
```


The entire cluster's YAML object is passed in as Helm values to the {{ cluster_root_chart() }}:
```yaml
        {% raw %}helm:
          values: "{{ `{{ toYaml . }}` }}"{% endraw %}
```

Additional global configuration parameters (such as details of the {{ source_repo() }} and the namespace where ArgoCD is running) set on the the **Account Root Application** are passed down as additional Helm parameters:
```yaml
        {% raw %}arameters:
          - name: "source.repo_url"
            value: "{{ .Values.source.repo_url }}"
          - name: "argo.namespace"
            value: "{{ .Values.argo.namespace }}"{% endraw %}
```


**Cluster Root Applications** are created in the ArgoCD namespace on the {{ management_cluster() }}:
```yaml
      {%raw %}destination:
        server: 'https://kubernetes.default.svc'
        namespace: {{ .Values.argo.namespace }}{% endraw %}
```


Given the config above, two **Cluster Root Applications** are generated:

```yaml
kind: Application
metadata:
  name: cluster.cluster1
spec:
  source:
    path: root-applications/ibm-mas-cluster-root
    helm:
      values: |-
        merge-key: dev/cluster1`
        account:
          id: dev
        cluster:
          id: cluster1
          url: https://api.cluster1.cakv.p3.openshiftapps.com:443
        ibm_operator_catalog:
          mas_catalog_version: v8-240430-amd64
      parameters:
        - name: source.repo_url
          value: "https://github.com/..."
        - name: argo.namespace
          value: "openshift-gitops"
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: openshift-gitops
```
```yaml
kind: Application
metadata:
  name: cluster.cluster2
spec:
  source:
    path: root-applications/ibm-mas-cluster-root
    helm:
      values: |-
        merge-key: dev/cluster2`
        account:
          id: dev
        cluster:
          id: cluster2
          url: https://api.cluster2.jsig.p3.openshiftapps.com:443
        ibm_operator_catalog:
          mas_catalog_version: v8-240405-amd64
      parameters:
        - name: source.repo_url
        - value: "https://github.com/..."
        - name: argo.namespace
          value: "openshift-gitops"
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: openshift-gitops
```



The Cluster Root Application
-------------------------------------------------------------------------------

**Cluster Root Applications** render the {{ cluster_root_chart() }} into the ArgoCD namespace of the {{ management_cluster() }}. 

The {{ cluster_root_chart() }} contains templates to conditionally render ArgoCD Applications that deploy cluster-wide resources to {{ target_clusters() }} once the configuration for those resources is present in the {{ config_repo() }}.

Application-specific configuration is held under a unique top-level field. For example, the `ibm_operator_catalog` field in our example above holds all configuration for the {{ gitops_repo_dir_link("cluster-applications/000-ibm-operator-catalog", "000-ibm-operator-catalog chart") }}. The {{ gitops_repo_file_link("root-applications/ibm-mas-cluster-root/templates/000-ibm-operator-catalog-app.yaml", "000-ibm-operator-catalog-app template") }} that renders this chart is guarded by:
```yaml
{% raw %}
{{- if not (empty .Values.ibm_operator_catalog) }}
{% endraw %}
```
Continuing with our example, because `ibm_operator_catalog` is present in the Helm values for both **Cluster Root Applications**, both will render the [000-ibm-operator-catalog-app template](root-applications/ibm-mas-cluster-root/templates/000-ibm-operator-catalog-app.yaml) into the respective {{ target_cluster() }}.

A simplified and abridged snippet of the [000-ibm-operator-catalog-app template](root-applications/ibm-mas-cluster-root/templates/000-ibm-operator-catalog-app.yaml) is shown below, followed by a breakdown of the purpose of each section:

```yaml
{% raw %}
kind: Application
metadata:
  name: operator-catalog.{{ .Values.cluster.id }}
spec:
  source:
    path: cluster-applications/000-ibm-operator-catalog
    plugin:
      name: argocd-vault-plugin-helm
      env:
        - name: HELM_VALUES
          value: |
            mas_catalog_version: "{{ .Values.ibm_operator_catalog.mas_catalog_version  }}"
  destination:
    server: {{ .Values.cluster.url }}
{% endraw %}
```

The template generates an **Operator Catalog Application** named according to its type (`operator-catalog`) and includes the cluster ID:
```yaml
{% raw %}kind: Application
metadata:
  name: operator-catalog.{{ .Values.cluster.id }}{% endraw %}
```

The **Operator Catalog Application** renders the {{ gitops_repo_dir_link("cluster-applications/000-ibm-operator-catalog", "000-ibm-operator-catalog chart") }}:
```yaml
{% raw %}spec:
  source:
    path: cluster-applications/000-ibm-operator-catalog{% endraw %}
```

Values are mapped from those in the **Cluster Root Application** manifest into the form expected by the {{ gitops_repo_dir_link("cluster-applications/000-ibm-operator-catalog", "000-ibm-operator-catalog chart") }}. 

```yaml
    {% raw %}plugin:
      name: argocd-vault-plugin-helm
      env:
        - name: HELM_VALUES
          value: |
            mas_catalog_version: "{{ .Values.ibm_operator_catalog.mas_catalog_version  }}"{% endraw %}
```


!!! info
    Some of these values (not shown here) will be [inline-path placeholders](https://argocd-vault-plugin.readthedocs.io/en/stable/howitworks/#inline-path-placeholders) for referencing secrets in the **Secrets Vault**, so we pass the values in via the AVP plugin source (rather than the `helm` source):


Finally, the resources in the {{ gitops_repo_dir_link("cluster-applications/000-ibm-operator-catalog", "000-ibm-operator-catalog chart") }} should created on the {{ target_cluster() }} in order to install the IBM operator catalog there:
```yaml
  {% raw %}destination:
  server: {{ .Values.cluster.url }}{% endraw %}
```


For our example configuration, two **Operator Catalog Applications** will be generated:

```yaml
kind: Application
metadata:
  name: operator-catalog.cluster1
spec:
  destination:
    server: https://api.cluster1.cakv.p3.openshiftapps.com:443
  source:
    path: cluster-applications/000-ibm-operator-catalog
    plugin:
      name: argocd-vault-plugin-helm
      env:
        - name: HELM_VALUES
          value: |
            mas_catalog_version: "v8-240430-amd64"
```

```yaml
kind: Application
metadata:
  name: operator-catalog.cluster2
spec:
  destination:
    server: https://api.cluster2.jsig.p3.openshiftapps.com:443
  source:
    path: cluster-applications/000-ibm-operator-catalog
    plugin:
      name: argocd-vault-plugin-helm
      env:
        - name: HELM_VALUES
          value: |
            mas_catalog_version: "v8-240405-amd64"
```


The other Application templates in the {{ cluster_root_chart() }} (e.g. {{ gitops_repo_file_link("root-applications/ibm-mas-cluster-root/templates/010-ibm-redhat-cert-manager-app.yaml", "010-ibm-redhat-cert-manager-app.yaml") }}, {{ gitops_repo_file_link("root-applications/ibm-mas-cluster-root/templates/020-ibm-dro-app.yaml", "020-ibm-dro-app.yaml") }} and so on) all follow this pattern and work in a similar way.

The {{ cluster_root_chart() }} also includes the [099-instance-appset.yaml template](root-applications/ibm-mas-cluster-root/templates/099-instance-appset.yaml) which generates a new **Instance Root Application Set** for each cluster.

The Instance Root Application Set
-------------------------------------------------------------------------------

The {{ instance_root_app_set() }}  generates a set of **Instance Root Applications** based on the configuration in the {{ config_repo() }}. It follows the same pattern as the {{ cluster_root_app_set() }} as described [above](#the-cluster-root-application-set). 

The key differences are:

- `merge-keys` in the instance-level configuation YAML files also contain a MAS instance ID, e.g. `dev/cluster1/instance1`.
- The generated **Instance Root Applications** source the {{ gitops_repo_dir_link("root-applications/ibm-mas-instance-root", "ibm-mas-instance-root Chart") }}.
- The Git File Generators look for a different set of named YAML files at the **instance** level in the {{ config_repo() }}:


A simplified and abridged snippet showing the Merge and Git File generators from the {{ instance_root_app_set() }} template is shown below:

```yaml
{% raw %}spec:
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
              - path: "{{ .Values.account.id }}/{{ .Values.cluster.id }}/*/ibm-mas-suite.yaml"{% endraw %}
```

Continuing with our example, let's add some additional instance-level config files to the {{ config_repo() }} (only showing `cluster1` this time for brevity). These are the files that the Git File Generators above are looking for.

```
├── dev
│   ├── cluster1
│   │   ├── ibm-mas-cluster-base.yaml
│   │   ├── ibm-operator-catalog.yaml
│   |   ├── instance1
│   |   │   ├── ibm-mas-instance-base.yaml
│   |   │   ├── ibm-mas-suite.yaml
```

Now let's take a look at the contents of the new instance-level files:

```
├── dev
│   ├── cluster1
│   │   ├── ibm-mas-cluster-base.yaml
│   │   ├── ibm-operator-catalog.yaml
│   |   ├── instance1
|   |   |   |-------------------------------------------
│   |   │   ├── ibm-mas-instance-base.yaml
|   |   |   |-------------------------------------------
|   |   |   |   merge-key: "dev/cluster1/instance1"
|   |   |   |   account:
|   |   |   |     id: dev
|   |   |   |   cluster:
|   |   |   |     id: cluster1
|   |   |   |     url: https://api.cluster1.cakv.p3.openshiftapps.com:443
|   |   |   |   instance:
|   |   |   |     id: instance1
|   |   |   |  
|   |   |   |-------------------------------------------
│   |   │   ├── ibm-mas-suite.yaml
|   |   |   |-------------------------------------------
|   |   |   |   merge-key: "dev/cluster1/instance1"
|   |   |   |   ibm_mas_suite:
|   |   |   |     mas_channel: "8.11.x"
...
```

As with the cluster-level config, all files contain the `merge-key`, but this times it also includes the MAS instance ID. This is used by the Merge generator to group together configuration into per-instance YAML objects for each {{ target_cluster() }}.

The `ibm-mas-instance-base.yaml` file contains global configuration for the instance on the {{ target_cluster() }}, including the `account.id`, and the `cluster.id`, the `cluster.url` and the `instance.id`.

The other YAML configuration files (such as `ibm-mas-suite.yaml` shown above) represent one type of instance-level resource that we wish to install on the {{ target_cluster() }}.

Given the config above, the {{instance_root_app_set }} would generate one YAML object:
```yaml
merge-key: "dev/cluster1/instance1"
account:
  id: dev
cluster:
  id: cluster1
  url: https://api.cluster1.cakv.p3.openshiftapps.com:443
instance:
  id: instance1
ibm_mas_suite:
  mas_channel: "8.11.x"
```

Follow the same pattern used in the {{ cluster_root_app_set() }} as described [above](#the-cluster-root-application-set), the  YAML object is used to render tje **Instance Root Application Set** template, generating an **Instance Root Application**:
```yaml
kind: Application
metadata:
  name: instance.cluster1.instance1
spec:
  source:
    path: root-applications/ibm-mas-instance-root
    helm:
      values: |-
        merge-key: dev/cluster1/instance1
        account:
          id: dev
        cluster:
          id: cluster1
          url: https://api.cluster1.cakv.p3.openshiftapps.com:443
        instance:
          id: instance1
        ibm_mas_suite:
          mas_channel: "8.11.x"
      parameters:
        - name: source.repo_url
          value: "https://github.com/..."
        - name: argo.namespace
          value: "openshift-gitops"
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: openshift-gitops
```

. 

The Instance Root Application
-------------------------------------------------------------------------------

**Instance Root Applications** render the {{ instance_root_chart() }} into the ArgoCD namespace of the {{ management_cluster() }}.

The {{ instance_root_chart() }} contains templates to conditionally render ArgoCD Applications that deploy MAS instances to **Target Clusters** once the configuration for the ArgoCD Application is present in the {{ config_repo() }}.

It follows the same pattern as the **Cluster Root Application** described [above](#the-cluster-root-application); specific applications are enabled once their configuration is pushed to the {{ config_repo() }}. For instance, the {{ gitops_repo_file_link("root-applications/ibm-mas-instance-root/templates/130-ibm-mas-suite-app.yaml", "130-ibm-mas-suite-app.yaml template") }} generates an Application that deploys the MAS `Suite` CR to the target cluster once configuration under the `ibm_mas_suite` key is present.

Some special templates are capable of generating multiple applications: 

- {{ gitops_repo_file_link("root-applications/ibm-mas-instance-root/templates/120-db2-databases-app.yaml", "120-db2-databases-app.yaml") }}
- {{ gitops_repo_file_link("root-applications/ibm-mas-instance-root/templates/130-ibm-mas-suite-configs-app.yaml", "130-ibm-mas-suite-configs-app.yaml") }}
- {{ gitops_repo_file_link("root-applications/ibm-mas-instance-root/templates/200-ibm-mas-workspaces.yaml", "200-ibm-mas-workspaces.yaml") }}
- {{ gitops_repo_file_link("root-applications/ibm-mas-instance-root/templates/510-550-ibm-mas-masapp-configs", "510-550-ibm-mas-masapp-configs") }}

These are used when there can be more than one instance of the *type* of resource that these Applications are responsible for managing. 

For example, MAS instances may require more than one DB2 Database. To accommodate this, we make use of the Helm `range` control structure to iterate over a list in YAML configuration files in the {{ config_repo()}}.

For instance, the `ibm-db2u-databases.yaml` configuration file contains:
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

The {{ gitops_repo_file_link("root-applications/ibm-mas-instance-root/templates/120-db2-databases-app.yaml", "120-db2-databases-app.yaml template") }} iterates over this list to generate multiple DB2 Database Applications configured as needed:

```yaml
{% raw %}
{{- range $i, $value := .Values.ibm_db2u_databases }}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: "db2-db.{{ $.Values.cluster.id }}.{{ $.Values.instance.id }}.{{ $value.mas_application_id }}"
...
{{- end}}
{% endraw %}
```


!!! info "Why not use ApplicationSets here?"
 
    We encountered some limitations when using ApplicationSets for this purpose. For instance, Applications generated by ApplicationSets do not participate in the [ArgoCD syncwave](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) with other Applications so we would have no way of ensuring that resources would be configured in the correct order. By using the Helm `range` control structure we generate "normal" Applications that do not suffer from this limitation. This means, for instance, that we can ensure that DB2 Databases are configured **before** attempting to provide the corresponding JDBC configuration to MAS.
