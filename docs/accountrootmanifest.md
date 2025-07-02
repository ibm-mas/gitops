Account Root Application Manifest
===============================================================================

The **Account Root Application** is created directly on the {{ management_cluster() }} running ArgoCD. It serves as the "entrypoint" to the MAS GitOps code and is where several key pieces of global configuration values are provided.

### Template

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root.<account-id>
  namespace: <argoapp-namespace>
spec:
  destination:
    namespace: <argoapp-namespace>
    server: https://kubernetes.default.svc
  project: <argo-project-rootapps>
  source:
    path: root-applications/ibm-mas-account-root
    repoURL: <source-repo-url>
    targetRevision: <source-repo-revision>
    helm:
      values: |
          account:
            id: <account-id>

          generator:
            repo_url: <config-repo>
            revision: <config-repo-revision>

          source:
            repo_url: <source-repo-url>
            revision: <source-repo-revision>
          
          argo:
            namespace: <argo-namespace>
            projects:
              rootapps: <argo-project-rootapps>
              apps: <argo-project-apps>

          avp:
            name: <avp-name>
            secret: <avp-secret>
            values_varname: <val-values-varname>

          auto_delete: <false|true>



            
    
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
```

### Parameters
#### `<source-repo-url>`
The URL of the Git repository containing the MAS GitOps Helm Charts, e.g. https://github.com/ibm-mas/gitops, aka the {{ source_repo() }}

#### `<source-repo-revision>`
The branch of `<source-repo-url>` to source the MAS GitOps Helm Charts from, e.g. `master`.

#### `<config-repo>`
The Git repository to source MAS cluster/instance configuration from, aka the {{ config_repo() }}

#### `<config-repo-revision>`
The revision of `<config-repo>` to source cluster/instance configuration from

#### `<account-id>`
The ID of the account this root application manages. This also determines the root folder in `<config-repo>`:`<config-repo-revision` to source cluster/instance configuration from, e.g. `dev`.

#### `<argo-namespace>`
The namespace in which ArgoCD is installed on the {{ management_cluster() }}. E.g. `openshift-gitops`, `argocd-worker`. This determines where Application and ApplicationSet resources will be created. It will also be used to annotate namespaces created by our charts with [argocd.argoproj.io/managed-by](https://argocd-operator.readthedocs.io/en/stable/usage/deploy-to-different-namespaces/).

#### `<argo-project-rootapps>`
The ArgoCD project in which to create root applications (including this Application and the root applications that it generates). The project must be configured to permit creation of `argoproj.io.Application` and `argoproj.io.ApplicationSet` resources in the `<argoapp-namespace>` of the cluster in which ArgoCD is running (i.e. `https://kubernetes.default.svc`).

#### `<argo-project-apps>`
The ArgoCD project in which to create the applications that deploy MAS resources (and their dependencies) to external MAS clusters. The project must be configured to permit creation of any resource in any namespace of all external MAS clusters targeted by this account.

#### `<avp-name>`
The name assigned to the ArgoCD Vault Plugin used for retrieving secrets. Defaults to `argocd-vault-plugin-helm`.

#### `<avp-secret>`
The name of the k8s secret containing the credentials for accessing the vault that AVP is linked with. Defaults to the empty string, which implies that these credentials have been configured already in the cluster.

#### `<avp-values_varname>`
The name of the environment variable used to pass values inline to AVP. Defaults to `HELM_VALUES`.


#### `auto_delete`
Defaults to `false`. 

If `true`, ArgoCD will be permitted to automatically delete ArgoCD Applications on the {{ management_cluster() }} and Kubernetes resources on the Target Clusters where it sees fit. This may happen because configuration is deleted from the {{ config_repo() }} for a particular Application or resource, or some change is made to the charts in the {{ source_repo() }}.

If `false`, ArgoCD will never delete a resource automatically. Instead, when ArgoCD deems that a resource should be removed, it will simply flag it as "pending removal" (with a small yellow trashcan icon). In order for an ArgoCD Application or resource on the Target Cluster to actually be deleted, a manual sync with the `Prune` optional enabled must be issued for the ArgoCD Application that owns the resource.

!!! note
    **For gitops versions >= 3.11.0 only**, when `auto_delete: false` is set, the [job-cleaner](https://github.com/ibm-mas/gitops/tree/mascore5637/cluster-applications/000-job-cleaner) cluster Application is enabled. This deploys a CronJob that periodically removes specific Job resources according to their `mas.ibm.com/job-cleanup-group` label. This is to prevent the accumulation of old versions of Job resources without the need to manually run `Prune` sync operations. Note that any Job resources created in existing environments by prior versions of Gitops will lack the `mas.ibm.com/job-cleanup-group` label and so will still need to be cleaned up manually

Since the **Cluster** and **Instance** root applications are generated by an Application Set, they behave slightly differently when `auto_delete` is `false`. They will be marked for removal if the `ibm-mas-cluster-base.yaml` or `ibm-mas-instance-base.yaml` files are removed from the {{ config_repo() }}. No indication will be given in the ArgoCD that this has occurred, but ArgoCD will stop synchronizing configuration changes to the Application. The user must manually issue a **delete** operation against the Application for it to be deleted.

!!! warning
    To mitigate risk of accident deletions / downtime in production systems, we strongly recommend that `auto_delete: true` is used in development environments only.

