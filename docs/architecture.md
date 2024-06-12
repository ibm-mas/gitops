Architecture
===============================================================================

The following diagram shows a high-level view of the various resources involved in a MAS GitOps deployment:

![Architecture](png/architecture.png)

The {{ source_repo() }} is a Git repository containing Helm Charts that define all of the Kubernetes resources required to deploy MAS instances using ArgoCD. The [ibm-mas/gitops]({{ gitops_repo_url }}/tree/{{ gitops_repo_branch }}) repository can be used directly as the {{ source_repo() }}, or a fork can be used if desired.

The {{ config_repo() }} represents the "source of truth" about the MAS instances being managed by ArgoCD. It contains configuration YAML files that provide the values for rendering the Helm Charts in the {{ source_repo() }}, defining how many MAS instances will be deployed and where and how each is configured. 

The {{ secrets_vault() }} is used to store sensitive values that should not be exposed in the {{ config_repo() }}. They are fetched at runtime using the [ArgoCD Vault Plugin](https://argocd-vault-plugin.readthedocs.io/en/stable/) from some backend implementation (e.g. AWS Secrets Manager). 

ArgoCD is installed and configured on some **Management Cluster**. A single **Account Root Application** is registered with ArgoCD. This tells ArgoCD how to access the {{ source_repo() }}, {{ config_repo() }} and {{ secrets_vault() }} and which **Account ID** (i.e. which top-level folder of the {{ config_repo() }})  to monitor for configuration files. 

The **Account Root Application** is the only Application that is created directly. We employ the [App of Apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern) whereby the **Account Root Application** uses the artifacts in the {{ source_repo() }}, {{ config_repo() }} and {{ secrets_vault() }} to dynamically generate (a tree of) further Applications (and ApplicationSets) which themselves may generate other Applications (and ApplicationSets) and/or configure a set of resources on one of the **Target Clusters**.

